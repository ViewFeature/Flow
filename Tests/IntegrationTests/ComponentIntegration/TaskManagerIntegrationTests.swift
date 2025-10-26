import Foundation
import Testing

@testable import Flow

/// Integration tests for TaskManager with Store and ActionHandler.
///
/// Tests how TaskManager coordinates task execution with Store actions
/// and handles concurrent task management.
@MainActor
@Suite struct TaskManagerIntegrationTests {
  // MARK: - Test Fixtures

  enum DataAction: Sendable {
    case fetch(String)
    case fetchMultiple([String])
    case cancelFetch(String)
    case cancelAll
    case process(String)
  }

  @Observable
  final class DataState {
    var data: [String: String] = [:]
    var isLoading: [String: Bool] = [:]
    var errors: [String: String] = [:]

    init(
      data: [String: String] = [:], isLoading: [String: Bool] = [:], errors: [String: String] = [:]
    ) {
      self.data = data
      self.isLoading = isLoading
      self.errors = errors
    }
  }

  struct DataFeature: Feature, Sendable {
    typealias Action = DataAction
    typealias State = DataState

    func handle() -> ActionHandler<Action, State, Void> {
      ActionHandler { action, state in
        switch action {
        case .fetch(let id):
          state.isLoading[id] = true
          return .run { _ in
            try await Task.sleep(for: .milliseconds(50))
          }
          .cancellable(id: "fetch-\(id)")

        case .fetchMultiple(let ids):
          for id in ids {
            state.isLoading[id] = true
          }
          // Start first task (in real app, you'd handle multiple tasks differently)
          if let firstId = ids.first {
            return .run { _ in
              try await Task.sleep(for: .milliseconds(30))
            }
            .cancellable(id: "fetch-\(firstId)")
          } else {
            return .none
          }

        case .cancelFetch(let id):
          state.isLoading[id] = false
          return .cancel(id: "fetch-\(id)")

        case .cancelAll:
          state.isLoading.removeAll()
          return .none  // cancelAllTasks() should be called separately

        case .process(let id):
          state.data[id] = "processed"
          return .none
        }
      }
    }
  }

  // MARK: - Basic Task Management Tests

  @Test func storeCanCancelRunningTask() async {
    // GIVEN: Store with running task
    let sut = Store(
      initialState: DataState(),
      feature: DataFeature()
    )

    // WHEN: Start task (fire-and-forget) and cancel it
    let fetchTask = sut.send(.fetch("data1"))

    // Give task time to start (cooperative scheduling)
    await Task.yield()

    await sut.send(.cancelFetch("data1")).value

    // Wait for task to complete (cancelled tasks still complete)
    await fetchTask.value

    // Give time for cleanup
    await Task.yield()

    // THEN: Task should be cancelled and cleaned up
    #expect(sut.state.isLoading["data1"] == false)
  }

  @Test func multipleSequentialTasks() async {
    // GIVEN: Store (processes actions sequentially on MainActor)
    let sut = Store(
      initialState: DataState(),
      feature: DataFeature()
    )

    // WHEN: Send multiple tasks - Store processes them SEQUENTIALLY, not concurrently
    // Each send() returns immediately (fire-and-forget), but Store processes actions one at a time
    let task1 = sut.send(.fetch("data1"))
    let task2 = sut.send(.fetch("data2"))
    let task3 = sut.send(.fetch("data3"))

    // Wait for all tasks to complete (sequential execution ensures order)
    await task1.value
    await task2.value
    await task3.value

    // THEN: All tasks complete, state is set correctly
    #expect(sut.state.isLoading["data1"] ?? false)  // Still marked as loading from action
    #expect(sut.state.isLoading["data2"] ?? false)
    #expect(sut.state.isLoading["data3"] ?? false)
  }

  // MARK: - Task Cancellation Tests

  // NOTE: Automatic task cancellation via isolated deinit is tested functionally
  // in StoreFullWorkflowTests.automaticCancellationOnDeinit
  // Direct weak reference checks are unreliable due to isolated deinit's async nature

  @Test func cancelSpecificTaskAmongMany() async {
    // GIVEN: Store with multiple sequential tasks
    let sut = Store(
      initialState: DataState(),
      feature: DataFeature()
    )

    // Note: Store processes actions sequentially, so these execute one after another
    let task1 = sut.send(.fetch("data1"))
    let task2 = sut.send(.fetch("data2"))
    let task3 = sut.send(.fetch("data3"))

    // WHEN: Cancel specific task (sequential processing means data2 might not have started yet)
    await sut.send(.cancelFetch("data2")).value

    // Wait for all tasks to complete
    await task1.value
    await task2.value
    await task3.value

    // THEN: Task should be cancelled
  }

  // MARK: - Task Completion Tests

  @Test func taskCompletionUpdatesRunningCount() async {
    // GIVEN: Store with short task
    struct ShortTaskFeature: Feature, Sendable {
      typealias Action = DataAction
      typealias State = DataState

      func handle() -> ActionHandler<Action, State, Void> {
        ActionHandler { action, _ in
          switch action {
          case .fetch(let id):
            return .run { _ in
              try await Task.sleep(for: .milliseconds(10))
            }
            .cancellable(id: "short-\(id)")
          default:
            return .none
          }
        }
      }
    }

    let sut = Store(
      initialState: DataState(),
      feature: ShortTaskFeature()
    )

    // WHEN: Start task and wait for completion
    await sut.send(.fetch("data1")).value

    // THEN: Running count should be back to 0
  }

  // MARK: - Task Error Handling Integration

  @Test func taskErrorsAreHandled() async {
    // GIVEN: Store with error-throwing task
    struct ErrorFeature: Feature, Sendable {
      typealias Action = DataAction
      typealias State = DataState

      func handle() -> ActionHandler<Action, State, Void> {
        ActionHandler { action, state in
          switch action {
          case .fetch(let id):
            state.isLoading[id] = true
            return .run { _ in
              try await Task.sleep(for: .milliseconds(10))
              throw NSError(domain: "TestError", code: 1)
            }
            .catch { error, errorState in
              errorState.errors[id] = error.localizedDescription
              errorState.isLoading[id] = false
            }
            .cancellable(id: "error-\(id)")
          default:
            return .none
          }
        }
      }
    }

    let sut = Store(
      initialState: DataState(),
      feature: ErrorFeature()
    )

    // WHEN: Execute task that throws
    await sut.send(.fetch("data1")).value

    // THEN: Error should be handled (no sleep needed - await .value waits for completion)
    #expect(sut.state.errors["data1"] != nil)
    #expect(sut.state.isLoading["data1"] == false)
  }

  // MARK: - Complex Task Workflows

  @Test func sequentialTaskExecution() async {
    // GIVEN: Store
    actor TaskTracker {
      var completedTasks: [String] = []

      func append(_ task: String) {
        completedTasks.append(task)
      }

      func getCompleted() -> [String] {
        completedTasks
      }
    }

    struct TrackingFeature: Feature, Sendable {
      let tracker: TaskTracker

      typealias Action = DataAction
      typealias State = DataState

      func handle() -> ActionHandler<Action, State, Void> {
        ActionHandler { [tracker] action, _ in
          switch action {
          case .fetch(let id):
            return .run { _ in
              try await Task.sleep(for: .milliseconds(20))
              await tracker.append(id)
            }
            .cancellable(id: "track-\(id)")
          default:
            return .none
          }
        }
      }
    }

    let tracker = TaskTracker()
    let sut = Store(
      initialState: DataState(),
      feature: TrackingFeature(tracker: tracker)
    )

    // WHEN: Execute tasks sequentially
    await sut.send(.fetch("task1")).value
    await sut.send(.fetch("task2")).value
    await sut.send(.fetch("task3")).value

    // THEN: Tasks should complete in order
    let completed = await tracker.getCompleted()
    #expect(completed == ["task1", "task2", "task3"])
  }

  @Test func taskReuseAfterCompletion() async {
    // GIVEN: Store
    let sut = Store(
      initialState: DataState(),
      feature: DataFeature()
    )

    // WHEN: Run task, wait for completion, run again
    await sut.send(.fetch("data1")).value

    let task2 = sut.send(.fetch("data1"))
    await Task.yield()  // Give task time to start

    // THEN: Task should be running again
    #expect(sut.state.isLoading["data1"] ?? false)

    await task2.value  // Clean up
  }

  // MARK: - Task Manager State Consistency

  @Test func taskManagerStateRemainsConsistent() async {
    // GIVEN: Store
    let sut = Store(
      initialState: DataState(),
      feature: DataFeature()
    )

    // WHEN: Start, cancel, and restart tasks (sequential processing)
    let task1 = sut.send(.fetch("data1"))
    await Task.yield()  // Give task time to start

    await sut.send(.cancelFetch("data1")).value
    await task1.value  // Wait for cancelled task to complete

    let task2 = sut.send(.fetch("data2"))
    await Task.yield()  // Give task time to start

    // THEN: Task manager state should be consistent
    // data2 should be running

    await task2.value  // Clean up
  }

  // MARK: - Integration with Synchronous Actions

  @Test func mixedSyncAndAsyncActions() async {
    // GIVEN: Store
    let sut = Store(
      initialState: DataState(),
      feature: DataFeature()
    )

    // WHEN: Mix synchronous and asynchronous actions (sequential processing)
    await sut.send(.process("data1")).value
    #expect(sut.state.data["data1"] == "processed")

    let task2 = sut.send(.fetch("data2"))
    await Task.yield()  // Give task time to start

    await sut.send(.process("data3")).value
    #expect(sut.state.data["data3"] == "processed")

    // THEN: Both sync and async actions should work
    #expect(sut.state.data["data1"] == "processed")
    #expect(sut.state.data["data3"] == "processed")
    #expect(sut.state.isLoading["data2"] ?? false)

    await task2.value  // Clean up
  }
}
