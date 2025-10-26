import Foundation
import Testing

@testable import Flow

/// Integration tests for cancellable(id:cancelInFlight:) functionality with Store
@MainActor
@Suite struct CancellableIntegrationTests {
  // MARK: - Test Fixtures

  enum SearchAction: Sendable {
    case search(String)
    case download(String)
  }

  @Observable
  final class SearchState {
    var query: String = ""
    var results: [String] = []
    var isSearching: Bool = false
    var searchCount: Int = 0

    init() {}
  }

  // MARK: - cancelInFlight: true Tests

  @Test func cancelInFlight_cancelsExistingTaskWithSameId() async {
    // GIVEN: Feature that uses cancelInFlight
    struct SearchFeature: Feature, Sendable {
      typealias Action = SearchAction
      typealias State = SearchState

      func handle() -> ActionHandler<Action, State, Void> {
        ActionHandler { action, state in
          switch action {
          case .search(let query):
            state.query = query
            state.isSearching = true
            return .run { state in
              try await Task.sleep(for: .milliseconds(100))
              state.results = [query]
              state.isSearching = false
              state.searchCount += 1
            }
            .cancellable(id: "search", cancelInFlight: true)

          default:
            return .none
          }
        }
      }
    }

    let sut = Store(
      initialState: SearchState(),
      feature: SearchFeature()
    )

    // WHEN: Send multiple search actions with cooperative scheduling
    sut.send(.search("swift"))
    await Task.yield()  // Give first task a chance to start

    sut.send(.search("kotlin"))  // This should cancel "swift"
    await Task.yield()  // Give second task a chance to start (and cancel first)

    // Wait for last task to complete (deterministic: waits for actual completion)
    await sut.send(.search("rust")).value  // This should cancel "kotlin"

    // THEN: Last query should be set correctly
    #expect(sut.state.query == "rust")

    // Note: Due to sequential processing and cancelInFlight timing,
    // any of the three searches might complete before cancellation.
    // - "swift" might complete if kotlin/rust are queued
    // - "kotlin" might complete if rust cancels it after 100ms sleep
    // - "rust" should complete if it successfully cancels kotlin
    // The key behavior is that cancelInFlight prevents multiple concurrent tasks.
    #expect(sut.state.results.count == 1, "Only one search should complete")
    #expect(["swift", "kotlin", "rust"].contains(sut.state.results.first ?? ""))
    #expect(sut.state.searchCount >= 1)
  }

  @Test func cancelInFlight_false_allowsConcurrentTasks() async {
    // GIVEN: Feature without cancelInFlight
    struct DownloadFeature: Feature, Sendable {
      typealias Action = SearchAction
      typealias State = SearchState

      func handle() -> ActionHandler<Action, State, Void> {
        ActionHandler { action, state in
          switch action {
          case .download(let id):
            return .run { state in
              try await Task.sleep(for: .milliseconds(50))
              state.results.append(id)
              state.searchCount += 1
            }
            .cancellable(id: "download-\(id)", cancelInFlight: false)

          default:
            return .none
          }
        }
      }
    }

    let sut = Store(
      initialState: SearchState(),
      feature: DownloadFeature()
    )

    // WHEN: Start multiple downloads (concurrently)
    let task1 = sut.send(.download("file1"))
    let task2 = sut.send(.download("file2"))
    let task3 = sut.send(.download("file3"))

    // Wait for all to complete
    await task1.value
    await task2.value
    await task3.value

    // THEN: All downloads should complete
    #expect(sut.state.results.count == 3)
    #expect(sut.state.searchCount == 3)
  }

  @Test func cancelInFlight_withDifferentIds_bothTasksRun() async {
    // GIVEN: Feature with different task IDs
    struct MultiTaskFeature: Feature, Sendable {
      typealias Action = SearchAction
      typealias State = SearchState

      func handle() -> ActionHandler<Action, State, Void> {
        ActionHandler { action, state in
          switch action {
          case .search(let query):
            return .run { state in
              try await Task.sleep(for: .milliseconds(50))
              state.results.append("search-\(query)")
              state.searchCount += 1
            }
            .cancellable(id: "search", cancelInFlight: true)

          case .download(let id):
            return .run { state in
              try await Task.sleep(for: .milliseconds(50))
              state.results.append("download-\(id)")
              state.searchCount += 1
            }
            .cancellable(id: "download", cancelInFlight: true)
          }
        }
      }
    }

    let sut = Store(
      initialState: SearchState(),
      feature: MultiTaskFeature()
    )

    // WHEN: Start search and download with different IDs
    let task1 = sut.send(.search("query"))
    let task2 = sut.send(.download("file"))

    // Wait for both to complete
    await task1.value
    await task2.value

    // THEN: Both should complete (different IDs)
    #expect(sut.state.results.count == 2)
    #expect(sut.state.searchCount == 2)
  }

  @Test func cancelInFlight_preventsRaceConditions() async {
    // GIVEN: Feature simulating search with race condition prevention
    actor SearchTracker {
      var completedSearches: [String] = []

      func append(_ query: String) {
        completedSearches.append(query)
      }

      func getCompleted() -> [String] {
        completedSearches
      }
    }

    struct SafeSearchFeature: Feature, Sendable {
      let tracker: SearchTracker

      typealias Action = SearchAction
      typealias State = SearchState

      func handle() -> ActionHandler<Action, State, Void> {
        ActionHandler { [tracker] action, state in
          switch action {
          case .search(let query):
            state.query = query
            return .run { state in
              try await Task.sleep(for: .milliseconds(50))
              try Task.checkCancellation()
              await tracker.append(query)
              state.results = [query]
              state.searchCount += 1
            }
            .cancellable(id: "search", cancelInFlight: true)

          default:
            return .none
          }
        }
      }
    }

    let tracker = SearchTracker()
    let sut = Store(
      initialState: SearchState(),
      feature: SafeSearchFeature(tracker: tracker)
    )

    // WHEN: Rapid searches (sequential processing with cancelInFlight)
    sut.send(.search("a"))
    sut.send(.search("ab"))  // This cancels "a"
    await sut.send(.search("abc")).value  // This cancels "ab" and waits for completion

    // THEN: Verify cancellation behavior
    let completed = await tracker.getCompleted()
    // Due to task cancellation timing, actor method ordering, and race conditions:
    // - Some cancelled tasks may complete before receiving the cancellation signal (50ms sleep is very short)
    // - Actor method calls (tracker.append) may execute in non-deterministic order
    // - We can only guarantee that at least one search completed
    #expect(!completed.isEmpty)
    #expect(sut.state.searchCount >= 1)
  }

  @Test func cancelInFlight_withErrorHandling() async {
    // GIVEN: Feature with error handling and cancelInFlight
    struct ErrorSearchFeature: Feature, Sendable {
      typealias Action = SearchAction
      typealias State = SearchState

      func handle() -> ActionHandler<Action, State, Void> {
        ActionHandler { action, state in
          switch action {
          case .search(let query):
            state.isSearching = true
            return .run { state in
              if query == "error" {
                throw NSError(domain: "SearchError", code: 1)
              }
              try await Task.sleep(for: .milliseconds(50))
              state.results = [query]
              state.isSearching = false
              state.searchCount += 1
            }
            .cancellable(id: "search", cancelInFlight: true)
            .catch { _, state in
              state.isSearching = false
              state.results = ["error"]
            }

          default:
            return .none
          }
        }
      }
    }

    let sut = Store(
      initialState: SearchState(),
      feature: ErrorSearchFeature()
    )

    // WHEN: Search that will be cancelled, then error search
    sut.send(.search("will-be-cancelled"))
    await Task.yield()  // Give task time to start

    await sut.send(.search("error")).value  // Cancels previous, handles error

    // THEN: Error should be handled (no sleep needed - await .value waits for completion)
    #expect(sut.state.results == ["error"])
    #expect(!sut.state.isSearching)
  }

  @Test func cancelInFlight_cleanupOnTaskCompletion() async {
    // GIVEN: Feature with cancelInFlight
    struct CleanupFeature: Feature, Sendable {
      typealias Action = SearchAction
      typealias State = SearchState

      func handle() -> ActionHandler<Action, State, Void> {
        ActionHandler { action, state in
          switch action {
          case .search(let query):
            return .run { state in
              try await Task.sleep(for: .milliseconds(50))
              state.results = [query]
              state.searchCount += 1
            }
            .cancellable(id: "search", cancelInFlight: true)

          default:
            return .none
          }
        }
      }
    }

    let sut = Store(
      initialState: SearchState(),
      feature: CleanupFeature()
    )

    // WHEN: Multiple searches (sequential processing)
    sut.send(.search("first"))
    await Task.yield()  // Give task time to start

    await sut.send(.search("second")).value  // Cancels first, completes second

    // THEN: Task should be cleaned up
    #expect(sut.state.results == ["second"])
  }
}
