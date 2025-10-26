import Foundation
import Testing

@testable import Flow

// MARK: - Test Helpers

private struct DummyError: Error {}

@Observable
private final class ErrorTestState {
  var error: FlowError?
  var data: String?
}

private struct ErrorTestFeature: Feature {
  typealias State = ErrorTestState

  enum Action: Sendable {
    case load
  }

  func handle() -> ActionHandler<Action, State, Void> {
    ActionHandler { action, state in
      switch action {
      case .load:
        return .run { _ in
          throw FlowError.networkError(
            underlying: DummyError()
          )
        }
        .catch { error, state in
          if let vfError = error as? FlowError {
            state.error = vfError
          }
        }
      }
    }
  }
}

/// Tests for FlowError to ensure user-friendly error messages.
@Suite("FlowError Tests")
struct FlowErrorTests {
  // MARK: - Validation Errors

  @Test("Validation error with suggestion")
  func validationErrorWithSuggestion() {
    let error = FlowError.validationFailed(
      reason: "Email format is invalid",
      suggestion: "Please enter a valid email like user@example.com"
    )

    #expect(
      error.errorDescription
        == "Validation failed: Email format is invalid. Please enter a valid email like user@example.com"
    )
    #expect(error.recoverySuggestion == "Please enter a valid email like user@example.com")
    #expect(error.failureReason == "Email format is invalid")
  }

  @Test("Validation error without suggestion")
  func validationErrorWithoutSuggestion() {
    let error = FlowError.validationFailed(
      reason: "Password too short"
    )

    #expect(error.errorDescription == "Validation failed: Password too short")
    #expect(error.recoverySuggestion == nil)
  }

  // MARK: - Network Errors

  @Test("Network error wrapping")
  func networkErrorWrapping() {
    struct DummyNetworkError: Error, LocalizedError {
      var errorDescription: String? { "Connection timeout" }
    }

    let underlying = DummyNetworkError()
    let error = FlowError.networkError(underlying: underlying)

    #expect(error.errorDescription?.contains("Connection timeout") == true)
    #expect(error.recoverySuggestion == "Check your internet connection and try again.")
  }

  // MARK: - Task Errors

  @Test("Task error with ID")
  func taskErrorWithId() {
    struct DummyTaskError: Error, LocalizedError {
      var errorDescription: String? { "API returned 404" }
    }

    let underlying = DummyTaskError()
    let error = FlowError.taskError(
      taskId: "fetch-user",
      underlying: underlying
    )

    #expect(error.errorDescription?.contains("fetch-user") == true)
    #expect(error.errorDescription?.contains("404") == true)
    #expect(error.recoverySuggestion?.contains("fetch-user") == true)
  }

  // MARK: - Middleware Errors

  @Test("Middleware error")
  func middlewareError() {
    struct DummyMiddlewareError: Error, LocalizedError {
      var errorDescription: String? { "Analytics unavailable" }
    }

    let underlying = DummyMiddlewareError()
    let error = FlowError.middlewareError(
      middlewareId: "AnalyticsMiddleware",
      underlying: underlying
    )

    #expect(error.errorDescription?.contains("AnalyticsMiddleware") == true)
    #expect(error.recoverySuggestion == "This is an internal error. Please report this issue.")
  }

  // MARK: - State Errors

  @Test("State error")
  func stateError() {
    let error = FlowError.stateError(
      reason: "Cannot checkout with empty cart"
    )

    #expect(error.errorDescription == "Invalid state: Cannot checkout with empty cart")
    #expect(error.failureReason == "Cannot checkout with empty cart")
  }

  // MARK: - Custom Errors

  @Test("Custom error without underlying")
  func customErrorWithoutUnderlying() {
    let error = FlowError.custom(
      message: "Feature unavailable in this region"
    )

    #expect(error.errorDescription == "Feature unavailable in this region")
    #expect(error.recoverySuggestion == nil)
  }

  @Test("Custom error with underlying")
  func customErrorWithUnderlying() {
    struct DummyError: Error, LocalizedError {
      var errorDescription: String? { "Database locked" }
    }

    let underlying = DummyError()
    let error = FlowError.custom(
      message: "Cannot save data",
      underlying: underlying
    )

    #expect(error.errorDescription?.contains("Cannot save data") == true)
    #expect(error.errorDescription?.contains("Database locked") == true)
  }

  // MARK: - String Conversion

  @Test("CustomStringConvertible")
  @MainActor
  func customStringConvertible() {
    let error = FlowError.validationFailed(reason: "Test")
    let description = String(describing: error)

    #expect(description.contains("Validation failed"))
  }

  @Test("CustomDebugStringConvertible")
  @MainActor
  func customDebugStringConvertible() {
    let error = FlowError.validationFailed(
      reason: "Email invalid",
      suggestion: "Use valid format"
    )

    let debugDescription = String(reflecting: error)

    #expect(debugDescription.contains("Description:"))
    #expect(debugDescription.contains("Reason:"))
    #expect(debugDescription.contains("Suggestion:"))
  }

  // MARK: - Integration with ActionTask

  @Test("Using FlowError in ActionTask.catch")
  @MainActor
  func usingInActionTaskCatch() async {
    let store = Store(
      initialState: ErrorTestState(),
      feature: ErrorTestFeature()
    )

    await store.send(.load).value

    #expect(store.state.error != nil)
    #expect(store.state.error?.errorDescription?.contains("Network error") == true)
  }
}
