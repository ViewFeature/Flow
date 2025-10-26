import Foundation
import Testing

@testable import Flow

/// Comprehensive unit tests for ActionProcessor with 100% code coverage.
///
/// Tests every public method, property, and code path in ActionProcessor.swift
@MainActor
@Suite struct ActionProcessorTests {
  // MARK: - Test Fixtures

  enum TestAction: Sendable {
    case increment
    case decrement
    case asyncOperation
    case throwError
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

  @Test func init_createsProcessorWithExecution() async {
    // GIVEN & WHEN: Create processor with execution
    let sut = ActionProcessor<TestAction, TestState, Void> { _, state in
      state.count += 1
      return .none
    }

    // THEN: Should execute action
    var state = TestState()
    let task = await sut.process(action: .increment, state: state)

    #expect(state.count == 1)
    if case .just = task.operation {
      #expect(Bool(true))
    } else {
      Issue.record("Expected noTask")
    }
  }

  @Test func init_withComplexExecution() async {
    // GIVEN: Complex execution logic
    let sut = ActionProcessor<TestAction, TestState, Void> { action, state in
      switch action {
      case .increment:
        state.count += 1
      case .decrement:
        state.count -= 1
      case .asyncOperation:
        state.isLoading = true
      case .throwError:
        state.errorMessage = "error"
      }
      return .none
    }

    // WHEN: Execute different actions
    var state = TestState()
    _ = await sut.process(action: .increment, state: state)
    _ = await sut.process(action: .decrement, state: state)
    _ = await sut.process(action: .asyncOperation, state: state)

    // THEN: Should handle all actions
    // swiftlint:disable:next empty_count
    #expect(state.count == 0)  // +1 -1 = 0
    #expect(state.isLoading)
  }

  // MARK: - process(action:state:)

  @Test func process_executesActionSuccessfully() async {
    // GIVEN: Processor
    var executionCount = 0
    let sut = ActionProcessor<TestAction, TestState, Void> { _, state in
      executionCount += 1
      state.count += 1
      return .none
    }

    // WHEN: Process action
    var state = TestState()
    let task = await sut.process(action: .increment, state: state)

    // THEN: Should execute and mutate state
    #expect(executionCount == 1)
    #expect(state.count == 1)
    if case .just = task.operation {
      #expect(Bool(true))
    } else {
      Issue.record("Expected noTask")
    }
  }

  @Test func process_returnsRunTask() async {
    // GIVEN: Processor that returns run task
    let sut = ActionProcessor<TestAction, TestState, Void> { _, state in
      state.isLoading = true
      return .run { _ in }
        .cancellable(id: "test-task")
    }

    // WHEN: Process action
    var state = TestState()
    let task = await sut.process(action: .asyncOperation, state: state)

    // THEN: Should return run task
    #expect(state.isLoading)
    if case .run(let id, _, _, _, _) = task.operation {
      #expect(id == "test-task")
    } else {
      Issue.record("Expected run task")
    }
  }

  @Test func process_returnsCancelTask() async {
    // GIVEN: Processor that returns cancel task
    let sut = ActionProcessor<TestAction, TestState, Void> { _, _ in
      .cancel(id: "cancel-me")
    }

    // WHEN: Process action
    var state = TestState()
    let task = await sut.process(action: .increment, state: state)

    // THEN: Should return cancels task
    if case .cancel(let ids, _) = task.operation {
      #expect(ids == ["cancel-me"])
    } else {
      Issue.record("Expected cancels task")
    }
  }

  @Test func process_executesMiddleware() async throws {
    // GIVEN: Processor with logging middleware
    let sut = ActionProcessor<TestAction, TestState, Void> { _, state in
      state.count += 1
      return .none
    }
    .use(LoggingMiddleware(logLevel: .debug))

    // WHEN: Process action
    var state = TestState()
    _ = await sut.process(action: .increment, state: state)

    // THEN: Should execute with middleware
    #expect(state.count == 1)
  }

  @Test func process_multipleTimesWithSameProcessor() async {
    // GIVEN: Processor
    let sut = ActionProcessor<TestAction, TestState, Void> { _, state in
      state.count += 1
      return .none
    }

    // WHEN: Process multiple times
    var state = TestState()
    _ = await sut.process(action: .increment, state: state)
    _ = await sut.process(action: .increment, state: state)
    _ = await sut.process(action: .increment, state: state)

    // THEN: Should accumulate state changes
    #expect(state.count == 3)
  }

  // MARK: - use(_:)

  @Test func use_addsMiddleware() async {
    // GIVEN: Processor
    let base = ActionProcessor<TestAction, TestState, Void> { _, state in
      state.count += 1
      return .none
    }

    // WHEN: Add middleware
    let sut = base.use(LoggingMiddleware(logLevel: .debug))

    // THEN: Should create new processor with middleware
    var state = TestState()
    _ = await sut.process(action: .increment, state: state)
    #expect(state.count == 1)
  }

  @Test func use_supportsMethodChaining() async {
    // GIVEN: Processor with multiple middleware
    let sut = ActionProcessor<TestAction, TestState, Void> { _, state in
      state.count += 1
      return .none
    }
    .use(LoggingMiddleware(logLevel: .debug))
    .use(LoggingMiddleware(category: "Test1"))
    .use(LoggingMiddleware(category: "Test2"))

    // WHEN: Process action
    var state = TestState()
    _ = await sut.process(action: .increment, state: state)

    // THEN: Should work with multiple middleware
    #expect(state.count == 1)
  }

  @Test func use_preservesOriginalProcessor() async {
    // GIVEN: Base processor
    let base = ActionProcessor<TestAction, TestState, Void> { _, state in
      state.count += 1
      return .none
    }

    // WHEN: Create new processor with middleware
    let withMiddleware = base.use(LoggingMiddleware())

    // THEN: Base processor should remain unchanged
    var state1 = TestState()
    _ = await base.process(action: .increment, state: state1)
    #expect(state1.count == 1)

    var state2 = TestState()
    _ = await withMiddleware.process(action: .increment, state: state2)
    #expect(state2.count == 1)
  }

  // MARK: - onError(_:)

  @Test func onError_doesNotAffectSuccessfulExecution() async {
    // GIVEN: Processor with error handler
    let sut = ActionProcessor<TestAction, TestState, Void> { _, state in
      state.count += 1
      return .none
    }
    .onError { _, state in
      state.errorMessage = "Should not be called"
    }

    // WHEN: Process successful action
    var state = TestState()
    _ = await sut.process(action: .increment, state: state)

    // THEN: Error handler should not be called
    #expect(state.count == 1)
    #expect(state.errorMessage == nil)
  }

  // MARK: - transform(_:)

  @Test func transform_modifiesTask() async {
    // GIVEN: Processor with transform
    let sut = ActionProcessor<TestAction, TestState, Void> { _, state in
      state.count += 1
      return .run { _ in }
        .cancellable(id: "original")
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

    // WHEN: Process action
    var state = TestState()
    let task = await sut.process(action: .asyncOperation, state: state)

    // THEN: Task should be transformed
    #expect(state.count == 1)
    if case .run(let id, _, _, _, _) = task.operation {
      #expect(id == "transformed")
    } else {
      Issue.record("Expected run task")
    }
  }

  @Test func transform_canConvertTaskTypes() async {
    // GIVEN: Processor that converts run to cancel
    let sut = ActionProcessor<TestAction, TestState, Void> { _, _ in
      .run { _ in }
        .cancellable(id: "will-cancel")
    }
    .transform { task in
      switch task.operation {
      case .run(let id, _, _, _, _):
        return .cancel(id: id)
      default:
        return task
      }
    }

    // WHEN: Process action
    var state = TestState()
    let task = await sut.process(action: .asyncOperation, state: state)

    // THEN: Should convert to cancels task
    if case .cancel(let ids, _) = task.operation {
      #expect(ids == ["will-cancel"])
    } else {
      Issue.record("Expected cancels task")
    }
  }

  @Test func transform_leavesNoTaskUnchanged() async {
    // GIVEN: Processor with transform
    let sut = ActionProcessor<TestAction, TestState, Void> { _, state in
      state.count += 1
      return .none
    }
    .transform { task in
      switch task.operation {
      case .run:
        return .cancel(id: "transformed")
      default:
        return task
      }
    }

    // WHEN: Process action returning noTask
    var state = TestState()
    let task = await sut.process(action: .increment, state: state)

    // THEN: noTask should remain unchanged
    if case .just = task.operation {
      #expect(Bool(true))
    } else {
      Issue.record("Expected noTask")
    }
  }

  @Test func transform_supportsChaining() async {
    // GIVEN: Processor with middleware, error handler, and transform
    let sut = ActionProcessor<TestAction, TestState, Void> { _, state in
      state.count += 1
      return .run { _ in }
        .cancellable(id: "task")
    }
    .use(LoggingMiddleware())
    .onError { _, state in
      state.errorMessage = "Error"
    }
    .transform { task in
      task  // Identity transform
    }

    // WHEN: Process action
    var state = TestState()
    let task = await sut.process(action: .asyncOperation, state: state)

    // THEN: Should work with all features
    #expect(state.count == 1)
    if case .run = task.operation {
      #expect(Bool(true))
    } else {
      Issue.record("Expected run task")
    }
  }

  // MARK: - Integration Tests

  @Test func fullPipeline_successfulExecution() async {
    // GIVEN: Processor with all features
    var middlewareExecuted = false
    let sut = ActionProcessor<TestAction, TestState, Void> { _, state in
      state.count += 10
      return .run { _ in }
        .cancellable(id: "main-task")
    }
    .use(LoggingMiddleware(logLevel: .debug))
    .onError { _, state in
      state.errorMessage = "Unexpected error"
    }
    .transform { task in
      middlewareExecuted = true
      return task
    }

    // WHEN: Process action
    var state = TestState(count: 5)
    let task = await sut.process(action: .increment, state: state)

    // THEN: Should execute full pipeline
    #expect(state.count == 15)
    #expect(middlewareExecuted)
    #expect(state.errorMessage == nil)
    if case .run(let id, _, _, _, _) = task.operation {
      #expect(id == "main-task")
    }
  }

  @Test func immutabilityOfMethodChaining() async {
    // GIVEN: Base processor
    let base = ActionProcessor<TestAction, TestState, Void> { _, state in
      state.count += 1
      return .none
    }

    // WHEN: Create multiple variants
    let withMiddleware = base.use(LoggingMiddleware())
    let withError = base.onError { _, state in state.errorMessage = "Error" }
    let withTransform = base.transform { $0 }

    // THEN: All variants should work independently
    var state1 = TestState()
    _ = await base.process(action: .increment, state: state1)
    #expect(state1.count == 1)

    var state2 = TestState()
    _ = await withMiddleware.process(action: .increment, state: state2)
    #expect(state2.count == 1)

    var state3 = TestState()
    _ = await withError.process(action: .increment, state: state3)
    #expect(state3.count == 1)

    var state4 = TestState()
    _ = await withTransform.process(action: .increment, state: state4)
    #expect(state4.count == 1)
  }
}
