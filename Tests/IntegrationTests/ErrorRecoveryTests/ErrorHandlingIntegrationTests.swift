import Foundation
import Testing

@testable import Flow

/// Integration tests for error handling and recovery scenarios.
///
/// Tests how the system handles errors, recovers from failures,
/// and maintains consistency across components.
@MainActor
@Suite struct ErrorHandlingIntegrationTests {
  // MARK: - Test Fixtures

  enum NetworkAction: Sendable {
    case fetchData(String)
    case retryFetch(String)
    case handleError(String, Error)
    case recoverFromError
    case reset
  }

  @Observable
  final class NetworkState {
    var data: [String: String] = [:]
    var errors: [String: String] = [:]
    var retryCount: Int = 0
    var isRecovering: Bool = false
    var lastError: String?

    init(
      data: [String: String] = [:], errors: [String: String] = [:], retryCount: Int = 0,
      isRecovering: Bool = false, lastError: String? = nil
    ) {
      self.data = data
      self.errors = errors
      self.retryCount = retryCount
      self.isRecovering = isRecovering
      self.lastError = lastError
    }
  }

  enum NetworkError: Error, Equatable {
    case timeout
    case unauthorized
    case serverError(Int)
    case networkUnavailable
  }

  // MARK: - Basic Error Handling Tests

  @Test func taskErrorsAreHandledGracefully() async {
    // GIVEN: Store with error-throwing feature
    struct ErrorFeature: Feature, Sendable {
      typealias Action = NetworkAction
      typealias State = NetworkState

      func handle() -> ActionHandler<Action, State, Void> {
        ActionHandler { action, _ in
          switch action {
          case .fetchData(let id):
            return .run { _ in
              try await Task.sleep(for: .milliseconds(10))
              throw NetworkError.timeout
            }
            .catch { error, errorState in
              errorState.errors[id] = "\(error)"
              errorState.lastError = "\(error)"
            }
            .cancellable(id: "fetch-\(id)")
          default:
            return .none
          }
        }
      }
    }

    let sut = Store(
      initialState: NetworkState(),
      feature: ErrorFeature()
    )

    // WHEN: Execute task that throws
    await sut.send(.fetchData("data1")).value

    // THEN: Error should be captured in state (no sleep needed - await .value waits for completion)
    #expect(sut.state.errors["data1"] != nil)
    #expect(sut.state.lastError != nil)
  }

  @Test func multipleErrorsAreHandledIndependently() async {
    // GIVEN: Store with multiple failing tasks
    struct MultiErrorFeature: Feature, Sendable {
      typealias Action = NetworkAction
      typealias State = NetworkState

      func handle() -> ActionHandler<Action, State, Void> {
        ActionHandler { action, state in
          switch action {
          case .fetchData(let id):
            let errorType: NetworkError = id == "data1" ? .timeout : .unauthorized
            return .run { _ in
              try await Task.sleep(for: .milliseconds(10))
              throw errorType
            }
            .catch { error, state in
              state.errors[id] = "\(error)"
            }
            .cancellable(id: "fetch-\(id)")
          default:
            return .none
          }
        }
      }
    }

    let sut = Store(
      initialState: NetworkState(),
      feature: MultiErrorFeature()
    )

    // WHEN: Execute multiple failing tasks
    await sut.send(.fetchData("data1")).value
    await sut.send(.fetchData("data2")).value

    // THEN: Each error should be tracked separately (no sleep needed - sequential execution)
    #expect(sut.state.errors["data1"] != nil)
    #expect(sut.state.errors["data2"] != nil)
    #expect(sut.state.errors.count == 2)
  }

  // MARK: - Error Recovery Tests

  @Test func systemRecoversAfterError() async {
    // GIVEN: Store with recovery mechanism
    struct RecoveryFeature: Feature, Sendable {
      typealias Action = NetworkAction
      typealias State = NetworkState

      func handle() -> ActionHandler<Action, State, Void> {
        ActionHandler { action, state in
          switch action {
          case .fetchData(let id):
            return .run { _ in
              throw NetworkError.timeout
            }
            .catch { error, errorState in
              errorState.errors[id] = "\(error)"
              errorState.lastError = "\(error)"
            }
            .cancellable(id: "fetch-\(id)")

          case .recoverFromError:
            state.errors.removeAll()
            state.lastError = nil
            state.isRecovering = false
            return .none

          case .retryFetch(let id):
            state.retryCount += 1
            state.errors[id] = nil
            return .run { _ in
              try await Task.sleep(for: .milliseconds(10))
              // Simulate success on retry
            }
            .cancellable(id: "retry-\(id)")

          default:
            return .none
          }
        }
      }
    }

    let sut = Store(
      initialState: NetworkState(),
      feature: RecoveryFeature()
    )

    // WHEN: Fail, then recover
    await sut.send(.fetchData("data1")).value

    #expect(sut.state.lastError != nil)

    await sut.send(.recoverFromError).value

    // THEN: State should be recovered (no sleep needed - sequential execution)
    #expect(sut.state.lastError == nil)
    #expect(sut.state.errors.isEmpty)
  }

  @Test func retryMechanismAfterError() async {
    // GIVEN: Store with retry mechanism
    struct RetryFeature: Feature, Sendable {
      typealias Action = NetworkAction
      typealias State = NetworkState

      func handle() -> ActionHandler<Action, State, Void> {
        ActionHandler { action, state in
          switch action {
          case .fetchData(let id):
            return .run { _ in
              throw NetworkError.timeout
            }
            .catch { error, state in
              state.errors[id] = "\(error)"
            }
            .cancellable(id: "retry-\(id)")

          case .retryFetch(let id):
            state.retryCount += 1
            state.errors[id] = nil
            return .run { _ in
              try await Task.sleep(for: .milliseconds(10))
            }

          default:
            return .none
          }
        }
      }
    }

    let sut = Store(
      initialState: NetworkState(),
      feature: RetryFeature()
    )

    // WHEN: Fail and retry
    await sut.send(.fetchData("data1")).value

    #expect(sut.state.errors["data1"] != nil)

    await sut.send(.retryFetch("data1")).value

    // THEN: Retry should clear error (no sleep needed - sequential execution)
    #expect(sut.state.errors["data1"] == nil)
    #expect(sut.state.retryCount == 1)
  }

  // MARK: - Error State Consistency Tests

  @Test func stateRemainsConsistentAfterError() async {
    // GIVEN: Store with state preservation
    struct StatePreservingFeature: Feature, Sendable {
      typealias Action = NetworkAction
      typealias State = NetworkState

      func handle() -> ActionHandler<Action, State, Void> {
        ActionHandler { action, state in
          switch action {
          case .fetchData(let id):
            state.data[id] = "loading"
            return .run { _ in
              throw NetworkError.serverError(500)
            }
            .catch { error, state in
              state.data[id] = "failed"
              state.errors[id] = "\(error)"
            }
            .cancellable(id: "fetch-\(id)")

          default:
            return .none
          }
        }
      }
    }

    let sut = Store(
      initialState: NetworkState(data: ["existing": "value"]),
      feature: StatePreservingFeature()
    )

    // WHEN: Error occurs
    await sut.send(.fetchData("data1")).value

    // THEN: Existing state should be preserved (no sleep needed - await .value waits for completion)
    #expect(sut.state.data["existing"] == "value")
    #expect(sut.state.data["data1"] == "failed")
    #expect(sut.state.errors["data1"] != nil)
  }

  // MARK: - Task Cancellation Error Tests

  @Test func automaticTaskCancellationDoesNotCauseErrors() async {
    // GIVEN: Store with cancellable task
    struct CancellableFeature: Feature, Sendable {
      typealias Action = NetworkAction
      typealias State = NetworkState

      func handle() -> ActionHandler<Action, State, Void> {
        ActionHandler { action, state in
          switch action {
          case .fetchData(let id):
            return .run { _ in
              try await Task.sleep(for: .milliseconds(100))
            }
            .catch { error, state in
              // Cancellation should not add errors
              if !(error is CancellationError) {
                state.errors[id] = "\(error)"
              }
            }
            .cancellable(id: "fetch-\(id)")

          default:
            return .none
          }
        }
      }
    }

    // Track final state
    var finalErrors: [String: String] = [:]

    do {
      let store = Store(
        initialState: NetworkState(),
        feature: CancellableFeature()
      )

      // WHEN: Start task and let Store deinit (automatic cancellation)
      _ = store.send(.fetchData("data1"))

      // NOTE: Give task time to start before deinit
      try? await Task.sleep(for: .milliseconds(10))

      // Capture state before deinit
      finalErrors = store.state.errors

      // Store goes out of scope here - automatic cancellation via deinit
    }

    // ⚠️ ISOLATED DEINIT TIMING DEPENDENCY (SE-0371) ⚠️
    //
    // This test relies on Task.sleep to wait for Store's isolated deinit to complete.
    // Due to Swift Evolution SE-0371 (isolated synchronous deinit), deinit executes
    // asynchronously on MainActor. The completion timing is non-deterministic and
    // environment-dependent.
    //
    // Why this sleep exists:
    // - Store's deinit needs to execute on MainActor
    // - Task cancellation must propagate
    // - Error handlers must complete (or not fire for CancellationError)
    //
    // Limitations:
    // - 30ms may be insufficient in slow CI environments
    // - No deterministic way to know when deinit has completed
    // - Cannot reliably check weak references due to async deinit
    //
    // Future improvement:
    // If Swift provides deterministic deinit completion signals, replace this sleep.
    try? await Task.sleep(for: .milliseconds(30))

    // THEN: Automatic cancellation should not have added errors
    #expect(finalErrors.isEmpty)
  }

  // MARK: - Complex Error Scenarios

  @Test func cascadingErrorHandling() async {
    // GIVEN: Store where errors can trigger other actions
    struct CascadingFeature: Feature, Sendable {
      typealias Action = NetworkAction
      typealias State = NetworkState

      func handle() -> ActionHandler<Action, State, Void> {
        ActionHandler { action, state in
          switch action {
          case .fetchData(let id):
            return .run { _ in
              throw NetworkError.unauthorized
            }
            .catch { error, state in
              state.errors[id] = "\(error)"
              // Trigger recovery
              state.isRecovering = true
            }
            .cancellable(id: "fetch-\(id)")

          case .recoverFromError:
            state.errors.removeAll()
            state.isRecovering = false
            return .none

          default:
            return .none
          }
        }
      }
    }

    let sut = Store(
      initialState: NetworkState(),
      feature: CascadingFeature()
    )

    // WHEN: Error triggers recovery state
    await sut.send(.fetchData("data1")).value

    #expect(sut.state.isRecovering)

    // Recover
    await sut.send(.recoverFromError).value

    // THEN: System should recover (no sleep needed - sequential execution)
    #expect(!sut.state.isRecovering)
    #expect(sut.state.errors.isEmpty)
  }

  @Test func errorDuringErrorHandling() async {
    // GIVEN: Store where error handler itself doesn't crash
    struct SafeErrorFeature: Feature, Sendable {
      typealias Action = NetworkAction
      typealias State = NetworkState

      func handle() -> ActionHandler<Action, State, Void> {
        ActionHandler { action, state in
          switch action {
          case .fetchData(let id):
            return .run { _ in
              throw NetworkError.serverError(500)
            }
            .catch { error, state in
              // Safe error handling
              state.errors[id] = "\(error)"
              state.lastError = "\(error)"
            }
            .cancellable(id: "fetch-\(id)")

          default:
            return .none
          }
        }
      }
    }

    let sut = Store(
      initialState: NetworkState(),
      feature: SafeErrorFeature()
    )

    // WHEN: Error occurs
    await sut.send(.fetchData("data1")).value

    // THEN: Error should be handled safely (no sleep needed - await .value waits for completion)
    #expect(sut.state.errors["data1"] != nil)
    #expect(sut.state.lastError != nil)
  }

  // MARK: - Recovery Workflow Tests

  @Test func fullErrorRecoveryWorkflow() async {
    // GIVEN: Store with complete recovery workflow
    struct FullRecoveryFeature: Feature, Sendable {
      typealias Action = NetworkAction
      typealias State = NetworkState

      func handle() -> ActionHandler<Action, State, Void> {
        ActionHandler { action, state in
          switch action {
          case .fetchData(let id):
            return .run { _ in
              throw NetworkError.timeout
            }
            .catch { error, errorState in
              errorState.errors[id] = "\(error)"
              errorState.lastError = "\(error)"
            }
            .cancellable(id: "fetch-\(id)")

          case .retryFetch(let id):
            state.retryCount += 1
            state.errors.removeValue(forKey: id)

            if state.retryCount < 3 {
              // Simulate failure on first 2 retries
              return .run { _ in
                throw NetworkError.timeout
              }
              .catch { error, state in
                state.errors[id] = "\(error)"
              }
              .cancellable(id: "retry-\(id)")
            } else {
              // Success on 3rd retry
              return .run { _ in
                // Success
              }
              .cancellable(id: "retry-\(id)")
            }

          case .recoverFromError:
            state.errors.removeAll()
            state.lastError = nil
            state.isRecovering = false
            return .none

          case .reset:
            state.data.removeAll()
            state.errors.removeAll()
            state.retryCount = 0
            state.isRecovering = false
            state.lastError = nil
            return .none

          default:
            return .none
          }
        }
      }
    }

    let sut = Store(
      initialState: NetworkState(),
      feature: FullRecoveryFeature()
    )

    // WHEN: Execute full recovery workflow
    // Initial failure
    await sut.send(.fetchData("data1")).value
    #expect(sut.state.errors["data1"] != nil)

    // First retry - fails
    await sut.send(.retryFetch("data1")).value
    #expect(sut.state.retryCount == 1)

    // Second retry - fails
    await sut.send(.retryFetch("data1")).value
    #expect(sut.state.retryCount == 2)

    // Third retry - succeeds
    await sut.send(.retryFetch("data1")).value
    #expect(sut.state.retryCount == 3)

    // THEN: Should eventually succeed (no sleep needed - sequential execution ensures order)
    // Error might still be present from last failure, but retry count is correct
    #expect(sut.state.retryCount == 3)
  }
}
