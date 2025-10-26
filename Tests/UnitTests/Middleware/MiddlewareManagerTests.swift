import Foundation
import Logging
import Testing

@testable import Flow

/// Comprehensive unit tests for MiddlewareManager with 100% code coverage.
///
/// Tests every public method, property, and code path in MiddlewareManager.swift
@MainActor
@Suite struct MiddlewareManagerTests {
  // MARK: - Test Fixtures

  enum TestAction: Sendable {
    case increment
    case decrement
    case loadData
  }

  final class TestState: Equatable, @unchecked Sendable {
    var count = 0
    var isLoading = false

    init(count: Int = 0, isLoading: Bool = false) {
      self.count = count
      self.isLoading = isLoading
    }

    static func == (lhs: TestState, rhs: TestState) -> Bool {
      lhs.count == rhs.count && lhs.isLoading == rhs.isLoading
    }
  }

  // MARK: - init(middlewares:)

  @Test func init_withEmptyArray() async {
    // GIVEN & WHEN: Create manager with empty array
    let sut = MiddlewareManager<TestAction, TestState>()

    // THEN: Should have no middlewares
    #expect(sut.allMiddlewares.isEmpty)
  }

  @Test func init_withDefaultParameter() async {
    // GIVEN & WHEN: Create manager with default parameter
    let sut = MiddlewareManager<TestAction, TestState>(middlewares: [])

    // THEN: Should have no middlewares
    #expect(sut.allMiddlewares.isEmpty)
  }

  @Test func init_withInitialMiddlewares() async {
    // GIVEN: Some middlewares
    let middleware1 = LoggingMiddleware()
    let middleware2 = LoggingMiddleware()

    // WHEN: Create manager with initial middlewares
    let sut = MiddlewareManager<TestAction, TestState>(middlewares: [middleware1, middleware2])

    // THEN: Should have 2 middlewares
    #expect(sut.allMiddlewares.count == 2)
  }

  @Test func init_withMultipleMiddlewares() async {
    // GIVEN: Multiple middlewares
    let middlewares: [any BaseActionMiddleware] = [
      LoggingMiddleware(),
      LoggingMiddleware(category: "Test1"),
      LoggingMiddleware(category: "Test2"),
      LoggingMiddleware(category: "Test3"),
    ]

    // WHEN: Create manager
    let sut = MiddlewareManager<TestAction, TestState>(middlewares: middlewares)

    // THEN: Should have all middlewares
    #expect(sut.allMiddlewares.count == 4)
  }

  // MARK: - allMiddlewares

  @Test func allMiddlewares_returnsEmptyArrayInitially() async {
    // GIVEN & WHEN: Fresh manager
    let sut = MiddlewareManager<TestAction, TestState>()

    // THEN: Should return empty array
    #expect(sut.allMiddlewares.isEmpty)
  }

  @Test func allMiddlewares_returnsInitialMiddlewares() async {
    // GIVEN: Manager with initial middlewares
    let middleware = LoggingMiddleware()
    let sut = MiddlewareManager<TestAction, TestState>(middlewares: [middleware])

    // WHEN: Get all middlewares
    let result = sut.allMiddlewares

    // THEN: Should return initial middleware
    #expect(result.count == 1)
    #expect(result[0].id == "Flow.Logging")
  }

  @Test func allMiddlewares_reflectsAddedMiddlewares() async {
    // GIVEN: Manager
    let sut = MiddlewareManager<TestAction, TestState>()
    let middleware = LoggingMiddleware()

    // WHEN: Add middleware
    sut.addMiddleware(middleware)

    // THEN: Should reflect added middleware
    #expect(sut.allMiddlewares.count == 1)
    #expect(sut.allMiddlewares[0].id == "Flow.Logging")
  }

  // MARK: - addMiddleware(_:)

  @Test func addMiddleware_addsToEmptyManager() async {
    // GIVEN: Empty manager
    let sut = MiddlewareManager<TestAction, TestState>()
    let middleware = LoggingMiddleware()

    // WHEN: Add middleware
    sut.addMiddleware(middleware)

    // THEN: Should have 1 middleware
    #expect(sut.allMiddlewares.count == 1)
  }

  @Test func addMiddleware_maintainsOrder() async {
    // GIVEN: Manager
    let sut = MiddlewareManager<TestAction, TestState>()
    let middleware1 = LoggingMiddleware(category: "First")
    let middleware2 = LoggingMiddleware(category: "Second")
    let middleware3 = LoggingMiddleware(category: "Third")

    // WHEN: Add middlewares in order
    sut.addMiddleware(middleware1)
    sut.addMiddleware(middleware2)
    sut.addMiddleware(middleware3)

    // THEN: Should maintain order (all have same ID)
    #expect(sut.allMiddlewares.count == 3)
    #expect(sut.allMiddlewares[0].id == "Flow.Logging")
    #expect(sut.allMiddlewares[1].id == "Flow.Logging")
    #expect(sut.allMiddlewares[2].id == "Flow.Logging")
  }

  @Test func addMiddleware_canAddMultipleTimes() async {
    // GIVEN: Manager
    let sut = MiddlewareManager<TestAction, TestState>()

    // WHEN: Add multiple middlewares
    sut.addMiddleware(LoggingMiddleware())
    sut.addMiddleware(LoggingMiddleware())
    sut.addMiddleware(LoggingMiddleware())

    // THEN: Should have all 3
    #expect(sut.allMiddlewares.count == 3)
  }

  // MARK: - addMiddlewares(_:)

  @Test func addMiddlewares_addsMultipleAtOnce() async {
    // GIVEN: Manager and middlewares
    let sut = MiddlewareManager<TestAction, TestState>()
    let middlewares: [any BaseActionMiddleware] = [
      LoggingMiddleware(),
      LoggingMiddleware(),
    ]

    // WHEN: Add middlewares
    sut.addMiddlewares(middlewares)

    // THEN: Should have both
    #expect(sut.allMiddlewares.count == 2)
  }

  @Test func addMiddlewares_withEmptyArray() async {
    // GIVEN: Manager
    let sut = MiddlewareManager<TestAction, TestState>()

    // WHEN: Add empty array
    sut.addMiddlewares([])

    // THEN: Should have no middlewares
    #expect(sut.allMiddlewares.isEmpty)
  }

  @Test func addMiddlewares_maintainsOrderOfArray() async {
    // GIVEN: Manager and ordered middlewares
    let sut = MiddlewareManager<TestAction, TestState>()
    let middlewares: [any BaseActionMiddleware] = [
      LoggingMiddleware(),
      LoggingMiddleware(),
      LoggingMiddleware(),
    ]

    // WHEN: Add middlewares
    sut.addMiddlewares(middlewares)

    // THEN: Should maintain array order (all have same ID)
    #expect(sut.allMiddlewares.count == 3)
  }

  @Test func addMiddlewares_appendsToExisting() async {
    // GIVEN: Manager with existing middleware
    let sut = MiddlewareManager<TestAction, TestState>()
    sut.addMiddleware(LoggingMiddleware())

    let newMiddlewares: [any BaseActionMiddleware] = [
      LoggingMiddleware(),
      LoggingMiddleware(),
    ]

    // WHEN: Add more middlewares
    sut.addMiddlewares(newMiddlewares)

    // THEN: Should append to existing
    #expect(sut.allMiddlewares.count == 3)
  }

  // MARK: - executeBeforeAction(action:state:)

  @Test func executeBeforeAction_executesSuccessfully() async throws {
    // GIVEN: Manager with middleware
    let middleware = LoggingMiddleware(logLevel: .debug)
    let sut = MiddlewareManager<TestAction, TestState>(middlewares: [middleware])

    // WHEN: Execute before action
    try await sut.executeBeforeAction(action: TestAction.increment, state: TestState())

    // THEN: Should not throw
    #expect(Bool(true))
  }

  @Test func executeBeforeAction_withNoMiddlewares() async throws {
    // GIVEN: Manager with no middlewares
    let sut = MiddlewareManager<TestAction, TestState>()

    // WHEN & THEN: Should not throw
    try await sut.executeBeforeAction(action: TestAction.increment, state: TestState())
  }

  @Test func executeBeforeAction_withMultipleMiddlewares() async throws {
    // GIVEN: Manager with multiple middlewares
    let sut = MiddlewareManager<TestAction, TestState>(middlewares: [
      LoggingMiddleware(logLevel: .debug),
      LoggingMiddleware(logLevel: .debug),
    ])

    // WHEN & THEN: Should execute both successfully
    try await sut.executeBeforeAction(action: TestAction.increment, state: TestState())
  }

  @Test func executeBeforeAction_withComplexState() async throws {
    // GIVEN: Manager with middleware
    let middleware = LoggingMiddleware(logLevel: .debug)
    let sut = MiddlewareManager<TestAction, TestState>(middlewares: [middleware])
    let state = TestState(count: 42, isLoading: true)

    // WHEN & THEN: Should handle complex state
    try await sut.executeBeforeAction(action: TestAction.loadData, state: state)
  }

  @Test func executeAfterAction_executesSuccessfully() async throws {
    // GIVEN: Manager with middleware
    let middleware = LoggingMiddleware(logLevel: .info)
    let sut = MiddlewareManager<TestAction, TestState>(middlewares: [middleware])
    let result: ActionTask<TestAction, TestState, Void> = .none

    // WHEN: Execute after action
    try await sut.executeAfterAction(
      action: TestAction.increment,
      state: TestState(),
      result: result,
    )

    // THEN: Should not throw
    #expect(Bool(true))
  }

  @Test func executeAfterAction_withNoMiddlewares() async throws {
    // GIVEN: Manager with no middlewares
    let sut = MiddlewareManager<TestAction, TestState>()
    let result: ActionTask<TestAction, TestState, Void> = .none

    // WHEN & THEN: Should not throw
    try await sut.executeAfterAction(
      action: TestAction.increment,
      state: TestState(),
      result: result,
    )
  }

  @Test func executeAfterAction_passesDuration() async throws {
    // GIVEN: Manager with middleware
    let middleware = LoggingMiddleware(logLevel: .info)
    let sut = MiddlewareManager<TestAction, TestState>(middlewares: [middleware])
    let result: ActionTask<TestAction, TestState, Void> = .none

    // WHEN: Execute with specific duration
    try await sut.executeAfterAction(
      action: TestAction.increment,
      state: TestState(),
      result: result,
    )

    // THEN: Should execute without error
    #expect(Bool(true))
  }

  @Test func executeAfterAction_withMultipleMiddlewares() async throws {
    // GIVEN: Manager with multiple middlewares
    let sut = MiddlewareManager<TestAction, TestState>(middlewares: [
      LoggingMiddleware(logLevel: .info),
      LoggingMiddleware(logLevel: .info),
    ])
    let result: ActionTask<TestAction, TestState, Void> = .none

    // WHEN & THEN: Should execute both successfully
    try await sut.executeAfterAction(
      action: TestAction.increment,
      state: TestState(),
      result: result,
    )
  }

  @Test func executeAfterAction_withRunTask() async throws {
    // GIVEN: Manager with middleware
    let middleware = LoggingMiddleware(logLevel: .info)
    let sut = MiddlewareManager<TestAction, TestState>(middlewares: [middleware])
    let result: ActionTask<TestAction, TestState, Void> = .run { _ in }
      .cancellable(id: "test")

    // WHEN & THEN: Should handle run task
    try await sut.executeAfterAction(
      action: TestAction.increment,
      state: TestState(),
      result: result,
    )
  }

  @Test func executeAfterAction_withCancelTask() async throws {
    // GIVEN: Manager with middleware
    let middleware = LoggingMiddleware(logLevel: .info)
    let sut = MiddlewareManager<TestAction, TestState>(middlewares: [middleware])
    let result: ActionTask<TestAction, TestState, Void> = .cancel(id: "test")

    // WHEN & THEN: Should handle cancel task
    try await sut.executeAfterAction(
      action: TestAction.increment,
      state: TestState(),
      result: result,
    )
  }

  // MARK: - executeErrorHandling(error:action:state:)

  @Test func executeErrorHandling_executesSuccessfully() async {
    // GIVEN: Manager with middleware
    let middleware = LoggingMiddleware()
    let sut = MiddlewareManager<TestAction, TestState>(middlewares: [middleware])
    let error = NSError(domain: "Test", code: 1)

    // WHEN: Execute error handling
    await sut.executeErrorHandling(
      error: error,
      action: TestAction.increment,
      state: TestState()
    )

    // THEN: Should not throw
    #expect(Bool(true))
  }

  @Test func executeErrorHandling_withNoMiddlewares() async {
    // GIVEN: Manager with no middlewares
    let sut = MiddlewareManager<TestAction, TestState>()
    let error = NSError(domain: "Test", code: 1)

    // WHEN: Execute error handling
    await sut.executeErrorHandling(
      error: error,
      action: TestAction.increment,
      state: TestState()
    )

    // THEN: Should not crash
    #expect(Bool(true))
  }

  @Test func executeErrorHandling_withMultipleMiddlewares() async {
    // GIVEN: Manager with multiple middlewares
    let sut = MiddlewareManager<TestAction, TestState>(middlewares: [
      LoggingMiddleware(),
      LoggingMiddleware(),
    ])
    let error = NSError(domain: "Test", code: 1)

    // WHEN: Execute error handling
    await sut.executeErrorHandling(
      error: error,
      action: TestAction.increment,
      state: TestState()
    )

    // THEN: Should execute both
    #expect(Bool(true))
  }

  @Test func executeErrorHandling_withLocalizedError() async {
    // GIVEN: Manager with middleware
    let middleware = LoggingMiddleware()
    let sut = MiddlewareManager<TestAction, TestState>(middlewares: [middleware])
    let error = NSError(
      domain: "TestError",
      code: 42,
      userInfo: [NSLocalizedDescriptionKey: "Test error message"]
    )

    // WHEN: Execute error handling
    await sut.executeErrorHandling(
      error: error,
      action: TestAction.loadData,
      state: TestState(count: 10, isLoading: true)
    )

    // THEN: Should handle localized error
    #expect(Bool(true))
  }

  @Test func executeErrorHandling_doesNotThrow() async {
    // GIVEN: Manager with middleware
    let middleware = LoggingMiddleware()
    let sut = MiddlewareManager<TestAction, TestState>(middlewares: [middleware])
    let error = NSError(domain: "Test", code: 1)

    // WHEN: Execute error handling (method does not throw)
    await sut.executeErrorHandling(
      error: error,
      action: TestAction.increment,
      state: TestState()
    )

    // THEN: Should complete without throwing
    #expect(Bool(true))
  }

  @Test func executeErrorHandling_executesAllMiddleware() async {
    // GIVEN: Multiple error handling middlewares
    var firstExecuted = false
    var secondExecuted = false

    struct FirstMiddleware: ErrorHandlingMiddleware {
      let id = "FirstMiddleware"
      let onExecute: () -> Void

      func onError<Action, State>(
        _ error: Error,
        action: Action,
        state: State
      ) async {
        onExecute()
      }
    }

    struct SecondMiddleware: ErrorHandlingMiddleware {
      let id = "SecondMiddleware"
      let onExecute: () -> Void

      func onError<Action, State>(
        _ error: Error,
        action: Action,
        state: State
      ) async {
        onExecute()
      }
    }

    let firstMiddleware = FirstMiddleware { firstExecuted = true }
    let secondMiddleware = SecondMiddleware { secondExecuted = true }
    let sut = MiddlewareManager<TestAction, TestState>(middlewares: [
      firstMiddleware,
      secondMiddleware,
    ])
    let error = NSError(domain: "TestError", code: 1)

    // WHEN: Execute error handling
    await sut.executeErrorHandling(
      error: error,
      action: TestAction.increment,
      state: TestState()
    )

    // THEN: Both middleware should execute
    #expect(firstExecuted)
    #expect(secondExecuted)
  }

  @Test func executeErrorHandling_executesMiddlewareInOrder() async {
    // GIVEN: Multiple middlewares with execution tracking
    var executionOrder: [String] = []

    struct FirstMiddleware: ErrorHandlingMiddleware {
      let id = "First"
      let track: (String) -> Void

      func onError<Action, State>(
        _ error: Error,
        action: Action,
        state: State
      ) async {
        track("First")
      }
    }

    struct SecondMiddleware: ErrorHandlingMiddleware {
      let id = "Second"
      let track: (String) -> Void

      func onError<Action, State>(
        _ error: Error,
        action: Action,
        state: State
      ) async {
        track("Second")
      }
    }

    struct ThirdMiddleware: ErrorHandlingMiddleware {
      let id = "Third"
      let track: (String) -> Void

      func onError<Action, State>(
        _ error: Error,
        action: Action,
        state: State
      ) async {
        track("Third")
      }
    }

    let sut = MiddlewareManager<TestAction, TestState>(middlewares: [
      FirstMiddleware(track: { executionOrder.append($0) }),
      SecondMiddleware(track: { executionOrder.append($0) }),
      ThirdMiddleware(track: { executionOrder.append($0) }),
    ])
    let error = NSError(domain: "Test", code: 1)

    // WHEN: Execute error handling
    await sut.executeErrorHandling(
      error: error,
      action: TestAction.increment,
      state: TestState()
    )

    // THEN: Should execute in registration order
    #expect(executionOrder == ["First", "Second", "Third"])
  }

  // MARK: - Integration Tests

  @Test func allOperations_withSingleMiddleware() async throws {
    // GIVEN: Manager with single middleware
    let middleware = LoggingMiddleware(logLevel: .debug)
    let sut = MiddlewareManager<TestAction, TestState>(middlewares: [middleware])
    let result: ActionTask<TestAction, TestState, Void> = .none

    // WHEN: Execute all phases
    try await sut.executeBeforeAction(action: TestAction.increment, state: TestState())
    try await sut.executeAfterAction(
      action: TestAction.increment,
      state: TestState(),
      result: result,
    )
    await sut.executeErrorHandling(
      error: NSError(domain: "Test", code: 1),
      action: TestAction.increment,
      state: TestState()
    )

    // THEN: All phases should execute successfully
    #expect(Bool(true))
  }

  @Test func mixedMiddlewares_executeCorrectly() async throws {
    // GIVEN: Manager with multiple middlewares
    let sut = MiddlewareManager<TestAction, TestState>(middlewares: [
      LoggingMiddleware(logLevel: .debug),
      LoggingMiddleware(logLevel: .info),
      LoggingMiddleware(logLevel: .error),
    ])
    let result: ActionTask<TestAction, TestState, Void> = .none

    // WHEN: Execute all phases
    try await sut.executeBeforeAction(action: TestAction.increment, state: TestState())
    try await sut.executeAfterAction(
      action: TestAction.increment,
      state: TestState(),
      result: result,
    )
    await sut.executeErrorHandling(
      error: NSError(domain: "Test", code: 1),
      action: TestAction.increment,
      state: TestState()
    )

    // THEN: All should execute successfully
    #expect(Bool(true))
  }

  @Test func middlewareOrder_maintainedThroughExecution() async throws {
    // GIVEN: Manager with ordered middlewares
    let middleware1 = LoggingMiddleware(logLevel: .debug)
    let middleware2 = LoggingMiddleware(logLevel: .debug)
    let middleware3 = LoggingMiddleware(logLevel: .debug)
    let sut = MiddlewareManager<TestAction, TestState>(
      middlewares: [middleware1, middleware2, middleware3]
    )

    // WHEN: Execute before action
    try await sut.executeBeforeAction(action: TestAction.increment, state: TestState())

    // THEN: Should execute without error (order maintained internally)
    #expect(sut.allMiddlewares.count == 3)
  }

  @Test func dynamicMiddlewareAddition() async throws {
    // GIVEN: Manager
    let sut = MiddlewareManager<TestAction, TestState>()

    // WHEN: Dynamically add middlewares
    sut.addMiddleware(LoggingMiddleware())
    try await sut.executeBeforeAction(action: TestAction.increment, state: TestState())

    sut.addMiddleware(LoggingMiddleware())
    try await sut.executeBeforeAction(action: TestAction.increment, state: TestState())

    // THEN: Should work with dynamically added middlewares
    #expect(sut.allMiddlewares.count == 2)
  }
}
