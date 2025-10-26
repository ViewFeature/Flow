import Foundation
import Testing

@testable import Flow

/// Tests for ActionTask priority functionality
@MainActor
@Suite struct ActionTaskPriorityTests {
  // MARK: - Test Fixtures

  enum TestAction: Sendable {
    case highPriority
    case lowPriority
  }

  @Observable
  final class TestState {
    var executionOrder: [String] = []

    init() {}
  }

  // MARK: - Priority Setting Tests

  @Test func priority_setsHighPriority() {
    // GIVEN: A run task
    let sut: ActionTask<TestAction, TestState, Void> = .run { _ in
      // Empty operation
    }

    // WHEN: Set high priority
    let result = sut.priority(.high)

    // THEN: Should have high priority
    switch result.operation {
    case .run(_, _, _, _, let priority):
      #expect(priority == .high)
    default:
      Issue.record("Expected run task")
    }
  }

  @Test func priority_setsLowPriority() {
    // GIVEN: A run task
    let sut: ActionTask<TestAction, TestState, Void> = .run { _ in
      // Empty operation
    }

    // WHEN: Set low priority
    let result = sut.priority(.low)

    // THEN: Should have low priority
    switch result.operation {
    case .run(_, _, _, _, let priority):
      #expect(priority == .low)
    default:
      Issue.record("Expected run task")
    }
  }

  @Test func priority_setsBackgroundPriority() {
    // GIVEN: A run task
    let sut: ActionTask<TestAction, TestState, Void> = .run { _ in
      // Empty operation
    }

    // WHEN: Set background priority
    let result = sut.priority(.background)

    // THEN: Should have background priority
    switch result.operation {
    case .run(_, _, _, _, let priority):
      #expect(priority == .background)
    default:
      Issue.record("Expected run task")
    }
  }

  @Test func priority_setsUserInitiatedPriority() {
    // GIVEN: A run task
    let sut: ActionTask<TestAction, TestState, Void> = .run { _ in
      // Empty operation
    }

    // WHEN: Set userInitiated priority
    let result = sut.priority(.userInitiated)

    // THEN: Should have userInitiated priority
    switch result.operation {
    case .run(_, _, _, _, let priority):
      #expect(priority == .userInitiated)
    default:
      Issue.record("Expected run task")
    }
  }

  @Test func priority_defaultIsNil() {
    // GIVEN: A run task without explicit priority
    let sut: ActionTask<TestAction, TestState, Void> = .run { _ in
      // Empty operation
    }

    // THEN: Priority should be nil (system default)
    switch sut.operation {
    case .run(_, _, _, _, let priority):
      #expect(priority == nil)
    default:
      Issue.record("Expected run task")
    }
  }

  // MARK: - Method Chaining Tests

  @Test func priority_chainsWithCancellable() {
    // GIVEN: A run task
    let sut: ActionTask<TestAction, TestState, Void> = .run { _ in
      // Empty operation
    }

    // WHEN: Chain priority and cancellable
    let result =
      sut
      .priority(.high)
      .cancellable(id: "test-task", cancelInFlight: true)

    // THEN: Should have both priority and cancellable ID
    switch result.operation {
    case .run(let id, _, _, let cancelInFlight, let priority):
      #expect(id == "test-task")
      #expect(cancelInFlight == true)
      #expect(priority == .high)
    default:
      Issue.record("Expected run task")
    }
  }

  @Test func priority_chainsWithCatch() {
    // GIVEN: A run task
    let sut: ActionTask<TestAction, TestState, Void> = .run { _ in
      // Empty operation
    }

    // WHEN: Chain priority and catch
    let result =
      sut
      .priority(.userInitiated)
      .catch { _, _ in
        // Error handler
      }

    // THEN: Should have both priority and error handler
    switch result.operation {
    case .run(_, _, let onError, _, let priority):
      #expect(priority == .userInitiated)
      #expect(onError != nil)
    default:
      Issue.record("Expected run task")
    }
  }

  @Test func priority_chainsWithAll() {
    // GIVEN: A run task
    let sut: ActionTask<TestAction, TestState, Void> = .run { _ in
      // Empty operation
    }

    // WHEN: Chain all methods
    let result =
      sut
      .priority(.high)
      .cancellable(id: "full-chain", cancelInFlight: false)
      .catch { _, _ in
        // Error handler
      }

    // THEN: Should preserve all configurations
    switch result.operation {
    case .run(let id, _, let onError, let cancelInFlight, let priority):
      #expect(id == "full-chain")
      #expect(cancelInFlight == false)
      #expect(priority == .high)
      #expect(onError != nil)
    default:
      Issue.record("Expected run task")
    }
  }

  @Test func priority_chainsInDifferentOrder() {
    // GIVEN: A run task
    let sut: ActionTask<TestAction, TestState, Void> = .run { _ in
      // Empty operation
    }

    // WHEN: Chain in different order
    let result =
      sut
      .cancellable(id: "order-test")
      .priority(.low)
      .catch { _, _ in
        // Error handler
      }

    // THEN: Should preserve all configurations regardless of order
    switch result.operation {
    case .run(let id, _, let onError, _, let priority):
      #expect(id == "order-test")
      #expect(priority == .low)
      #expect(onError != nil)
    default:
      Issue.record("Expected run task")
    }
  }

  // MARK: - Priority Replacement Tests

  @Test func priority_replacesExistingPriority() {
    // GIVEN: A task with high priority
    let sut: ActionTask<TestAction, TestState, Void> = .run { _ in
      // Empty operation
    }
    .priority(.high)

    // WHEN: Set different priority
    let result = sut.priority(.low)

    // THEN: Should have the new priority
    switch result.operation {
    case .run(_, _, _, _, let priority):
      #expect(priority == .low)
    default:
      Issue.record("Expected run task")
    }
  }

  // MARK: - Non-Run Task Tests

  @Test func priority_hasNoEffectOnNoneTask() {
    // GIVEN: A none task
    let sut: ActionTask<TestAction, TestState, Void> = .none

    // WHEN: Try to set priority
    let result = sut.priority(.high)

    // THEN: Should remain as none task
    switch result.operation {
    case .just:
      #expect(true, "Task should remain as none")
    default:
      Issue.record("Expected none task to remain unchanged")
    }
  }

  @Test func priority_hasNoEffectOnCancelTask() {
    // GIVEN: A cancel task
    let sut: ActionTask<TestAction, TestState, Void> = .cancel(id: "test")

    // WHEN: Try to set priority
    let result = sut.priority(.high)

    // THEN: Should remain as cancel task
    switch result.operation {
    case .cancel(let ids, _):
      #expect(ids == ["test"])
    default:
      Issue.record("Expected cancel task to remain unchanged")
    }
  }
}
