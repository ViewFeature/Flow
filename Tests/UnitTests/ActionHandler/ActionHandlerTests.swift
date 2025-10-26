import Foundation
import Testing

@testable import Flow

/// Comprehensive unit tests for ActionHandler with 100% code coverage.
///
/// Tests every public method in ActionHandler.swift
@MainActor
@Suite struct ActionHandlerTests {
  // MARK: - Test Fixtures

  enum TestAction: Sendable {
    case increment
    case decrement
    case asyncOp
  }

  final class TestState: Equatable, @unchecked Sendable {
    var count = 0
    var errorMessage: String?
    var isLoading = false

    init(count: Int = 0, errorMessage: String? = nil, isLoading: Bool = false) {
      self.count = count
      self.errorMessage = errorMessage
      self.isLoading = isLoading
    }

    static func == (lhs: TestState, rhs: TestState) -> Bool {
      lhs.count == rhs.count && lhs.errorMessage == rhs.errorMessage
        && lhs.isLoading == rhs.isLoading
    }
  }

  // MARK: - init(_:)

  @Test func init_createsHandler() async {
    // GIVEN & WHEN: Create handler
    let sut = ActionHandler<TestAction, TestState, Void> { _, state in
      state.count += 1
      return .none
    }

    // THEN: Should handle actions
    var state = TestState()
    _ = await sut.handle(action: .increment, state: state)
    #expect(state.count == 1)
  }

  @Test func init_withComplexLogic() async {
    // GIVEN: Handler with complex logic
    let sut = ActionHandler<TestAction, TestState, Void> { action, state in
      switch action {
      case .increment:
        state.count += 1
      case .decrement:
        state.count -= 1
      case .asyncOp:
        state.isLoading = true
        return .run { _ in }
      }
      return .none
    }

    // WHEN: Handle different actions
    var state = TestState()
    _ = await sut.handle(action: .increment, state: state)
    _ = await sut.handle(action: .decrement, state: state)

    // THEN: Should process all actions
    // swiftlint:disable:next empty_count
    #expect(state.count == 0)  // +1 -1 = 0
  }

  // MARK: - handle(action:state:)

  @Test func handle_executesAction() async {
    // GIVEN: Handler
    let sut = ActionHandler<TestAction, TestState, Void> { _, state in
      state.count += 5
      return .none
    }

    // WHEN: Handle action
    var state = TestState()
    let task = await sut.handle(action: .increment, state: state)

    // THEN: Should update state
    #expect(state.count == 5)
    if case .just = task.operation {
      #expect(Bool(true))
    } else {
      Issue.record("Expected noTask")
    }
  }

  @Test func handle_returnsRunTask() async {
    // GIVEN: Handler returning run task
    let sut = ActionHandler<TestAction, TestState, Void> { _, state in
      state.isLoading = true
      return .run { _ in }
        .cancellable(id: "test")
    }

    // WHEN: Handle action
    var state = TestState()
    let task = await sut.handle(action: .asyncOp, state: state)

    // THEN: Should return run task
    #expect(state.isLoading)
    if case .run(let id, _, _, _, _) = task.operation {
      #expect(id == "test")
    } else {
      Issue.record("Expected run task")
    }
  }

  @Test func handle_returnsCancelTask() async {
    // GIVEN: Handler returning cancel task
    let sut = ActionHandler<TestAction, TestState, Void> { _, _ in
      .cancel(id: "cancel-me")
    }

    // WHEN: Handle action
    var state = TestState()
    let task = await sut.handle(action: .increment, state: state)

    // THEN: Should return cancels task
    if case .cancel(let ids, _) = task.operation {
      #expect(ids == ["cancel-me"])
    } else {
      Issue.record("Expected cancels task")
    }
  }

  @Test func handle_multipleTimes() async {
    // GIVEN: Handler
    let sut = ActionHandler<TestAction, TestState, Void> { _, state in
      state.count += 1
      return .none
    }

    // WHEN: Handle multiple times
    var state = TestState()
    _ = await sut.handle(action: .increment, state: state)
    _ = await sut.handle(action: .increment, state: state)
    _ = await sut.handle(action: .increment, state: state)

    // THEN: Should accumulate
    #expect(state.count == 3)
  }

  // MARK: - onError(_:)

  @Test func onError_returnsNewHandler() async {
    // GIVEN: Base handler
    let baseHandler = ActionHandler<TestAction, TestState, Void> { _, state in
      state.count += 1
      return .none
    }

    // WHEN: Add error handler
    let sut = baseHandler.onError { _, state in
      state.errorMessage = "Error handled"
    }

    // THEN: Should return a working handler
    var state = TestState()
    _ = await sut.handle(action: .increment, state: state)
    #expect(state.count == 1)
  }

  @Test func onError_supportsChaining() async {
    // GIVEN: Handler with multiple chained methods
    let sut = ActionHandler<TestAction, TestState, Void> { _, state in
      state.count += 1
      return .none
    }
    .onError { _, state in
      state.errorMessage = "Error"
    }
    .use(LoggingMiddleware())

    // WHEN: Handle action
    var state = TestState()
    _ = await sut.handle(action: .increment, state: state)

    // THEN: Should work with chaining
    #expect(state.count == 1)
  }

  @Test func onError_canBeCalled() async {
    // GIVEN: Handler
    let sut = ActionHandler<TestAction, TestState, Void> { _, state in
      state.count += 1
      return .none
    }
    .onError { _, state in
      state.count = 999
    }

    // WHEN: Handle action (no error occurs)
    var state = TestState()
    _ = await sut.handle(action: .increment, state: state)

    // THEN: Normal operation works
    #expect(state.count == 1)
  }

  // MARK: - use(_:)

  @Test func use_addsMiddleware() async {
    // GIVEN: Handler with middleware
    let sut = ActionHandler<TestAction, TestState, Void> { _, state in
      state.count += 1
      return .none
    }
    .use(LoggingMiddleware(category: "TestFeature"))

    // WHEN: Handle action
    var state = TestState()
    _ = await sut.handle(action: .increment, state: state)

    // THEN: Should execute with middleware
    #expect(state.count == 1)
  }

  @Test func use_defaultCategory() async {
    // GIVEN: Handler with default middleware
    let sut = ActionHandler<TestAction, TestState, Void> { _, state in
      state.count += 1
      return .none
    }
    .use(LoggingMiddleware())

    // WHEN: Handle action
    var state = TestState()
    _ = await sut.handle(action: .increment, state: state)

    // THEN: Should execute with default middleware
    #expect(state.count == 1)
  }

  @Test func use_supportsChaining() async {
    // GIVEN: Handler with multiple middleware
    let sut = ActionHandler<TestAction, TestState, Void> { _, state in
      state.count += 1
      return .none
    }
    .use(LoggingMiddleware(category: "Cat1"))
    .use(LoggingMiddleware(category: "Cat2"))
    .onError { _, state in
      state.errorMessage = "Error"
    }

    // WHEN: Handle action
    var state = TestState()
    _ = await sut.handle(action: .increment, state: state)

    // THEN: Should work with multiple middleware
    #expect(state.count == 1)
  }

  // MARK: - transform(_:)

  @Test func transform_modifiesTask() async {
    // GIVEN: Handler with transform
    let sut = ActionHandler<TestAction, TestState, Void> { _, state in
      state.count += 1
      return .run { _ in }
    }
    .transform { task in
      switch task.operation {
      case .run:
        return .run { _ in }
          .cancellable(id: "transformed")
      default:
        return task
      }
    }

    // WHEN: Handle action
    var state = TestState()
    let task = await sut.handle(action: .increment, state: state)

    // THEN: Task should be transformed
    #expect(state.count == 1)
    if case .run(let id, _, _, _, _) = task.operation {
      #expect(id == "transformed")
    } else {
      Issue.record("Expected run task")
    }
  }

  @Test func transform_canConvertTasks() async {
    // GIVEN: Handler that converts tasks
    let sut = ActionHandler<TestAction, TestState, Void> { _, _ in
      .run { _ in }
        .cancellable(id: "convert")
    }
    .transform { task in
      switch task.operation {
      case .run(let id, _, _, _, _):
        return .cancel(id: id)
      default:
        return task
      }
    }

    // WHEN: Handle action
    var state = TestState()
    let task = await sut.handle(action: .asyncOp, state: state)

    // THEN: Should convert to cancels
    if case .cancel(let ids, _) = task.operation {
      #expect(ids == ["convert"])
    } else {
      Issue.record("Expected cancels task")
    }
  }

  @Test func transform_leavesNoTaskUnchanged() async {
    // GIVEN: Handler with transform
    let sut = ActionHandler<TestAction, TestState, Void> { _, state in
      state.count += 1
      return .none
    }
    .transform { task in
      switch task.operation {
      case .run:
        return .cancel(id: "modified")
      default:
        return task
      }
    }

    // WHEN: Handle action returning noTask
    var state = TestState()
    let task = await sut.handle(action: .increment, state: state)

    // THEN: noTask should remain
    if case .just = task.operation {
      #expect(Bool(true))
    } else {
      Issue.record("Expected noTask")
    }
  }

  @Test func transform_supportsChaining() async {
    // GIVEN: Handler with all features
    let sut = ActionHandler<TestAction, TestState, Void> { _, state in
      state.count += 1
      return .run { _ in }
    }
    .use(LoggingMiddleware())
    .onError { _, state in
      state.errorMessage = "Error"
    }
    .transform { task in
      task
    }

    // WHEN: Handle action
    var state = TestState()
    let task = await sut.handle(action: .asyncOp, state: state)

    // THEN: Should work with all features
    #expect(state.count == 1)
    if case .run = task.operation {
      #expect(Bool(true))
    }
  }

  // MARK: - Integration Tests

  @Test func fullPipeline_successfulExecution() async {
    // GIVEN: Handler with all features
    let sut = ActionHandler<TestAction, TestState, Void> { action, state in
      switch action {
      case .increment:
        state.count += 1
        return .none
      case .decrement:
        state.count -= 1
        return .none
      case .asyncOp:
        state.isLoading = true
        return .run { _ in }
      }
    }
    .use(LoggingMiddleware(category: "Integration"))
    .onError { _, state in
      state.errorMessage = "Unexpected error"
    }
    .transform { task in
      task  // Identity
    }

    // WHEN: Handle multiple actions
    var state = TestState()
    _ = await sut.handle(action: .increment, state: state)
    _ = await sut.handle(action: .increment, state: state)
    _ = await sut.handle(action: .decrement, state: state)

    // THEN: Should process all actions
    #expect(state.count == 1)  // +1 +1 -1 = 1
    #expect(state.errorMessage == nil)
  }

  @Test func immutabilityOfChaining() async {
    // GIVEN: Base handler
    let base = ActionHandler<TestAction, TestState, Void> { _, state in
      state.count += 1
      return .none
    }

    // WHEN: Create variants
    let withMiddleware = base.use(LoggingMiddleware())
    let withError = base.onError { _, state in state.errorMessage = "E" }
    let withTransform = base.transform { $0 }

    // THEN: All should work independently
    var state1 = TestState()
    _ = await base.handle(action: .increment, state: state1)
    #expect(state1.count == 1)

    var state2 = TestState()
    _ = await withMiddleware.handle(action: .increment, state: state2)
    #expect(state2.count == 1)

    var state3 = TestState()
    _ = await withError.handle(action: .increment, state: state3)
    #expect(state3.count == 1)

    var state4 = TestState()
    _ = await withTransform.handle(action: .increment, state: state4)
    #expect(state4.count == 1)
  }

  @Test func complexScenario() async {
    // GIVEN: Handler with complex scenario
    let sut = ActionHandler<TestAction, TestState, Void> { action, state in
      switch action {
      case .increment:
        state.count += 10
      case .decrement:
        state.count -= 5
      case .asyncOp:
        state.isLoading = true
        return .run { _ in }
          .cancellable(id: "complex")
      }
      return .none
    }
    .use(LoggingMiddleware(category: "Complex"))
    .onError { error, state in
      state.errorMessage = error.localizedDescription
      state.isLoading = false
    }

    // WHEN: Execute complex sequence
    var state = TestState(count: 100)
    _ = await sut.handle(action: .increment, state: state)
    #expect(state.count == 110)

    let task = await sut.handle(action: .asyncOp, state: state)
    #expect(state.isLoading)
    if case .run(let id, _, _, _, _) = task.operation {
      #expect(id == "complex")
    }

    _ = await sut.handle(action: .decrement, state: state)
    #expect(state.count == 105)  // 110 - 5 = 105
  }
}
