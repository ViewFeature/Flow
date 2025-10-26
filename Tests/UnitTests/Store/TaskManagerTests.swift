import Foundation
import Testing

@testable import Flow

/// Comprehensive unit tests for TaskManager with 100% code coverage.
///
/// Tests every public method and code path in TaskManager.swift
/// Uses Task.isCancelled for deterministic assertions instead of timing-dependent checks.
@MainActor
@Suite struct TaskManagerTests {
  // MARK: - executeTask(id:operation:onError:)

  @Test func executeTask_executesOperationSuccessfully() async {
    let sut = TaskManager()
    // GIVEN: A flag
    var didExecute = false

    // WHEN: Execute a task
    let task = sut.executeTask(id: "test", operation: { didExecute = true }, onError: nil)

    // Wait for execution
    await task.value

    // THEN: Operation should have executed
    #expect(didExecute)
  }

  @Test func executeTask_callsErrorHandlerOnFailure() async {
    let sut = TaskManager()
    // GIVEN: Error handler
    let testError = NSError(domain: "Test", code: 1)
    var capturedError: Error?

    // WHEN: Execute a task that throws
    let task = sut.executeTask(
      id: "failing",
      operation: { throw testError },
      onError: { error in capturedError = error }
    )

    // Wait for error handling
    await task.value

    // THEN: Error handler should have been called
    #expect(capturedError != nil)
  }

  @Test func executeTask_doesNotCrashWhenNilErrorHandler() async {
    let sut = TaskManager()
    // GIVEN & WHEN: Execute a task that throws with nil handler
    let task = sut.executeTask(
      id: "no-handler", operation: { throw NSError(domain: "Test", code: 1) }, onError: nil)

    // Wait
    await task.value

    // THEN: Should not crash
    #expect(Bool(true))
  }

  @Test func executeTask_cancelsExistingTaskWithSameId() async {
    let sut = TaskManager()
    // GIVEN: A long-running task
    var firstCompleted = false

    let task1 = sut.executeTask(
      id: "dup",
      operation: {
        try await Task.sleep(nanoseconds: 200_000_000)  // 200ms
        firstCompleted = true
      },
      onError: nil
    )

    // WHEN: Execute second task with same ID
    let task2 = sut.executeTask(id: "dup", operation: {}, onError: nil)

    await task2.value

    // THEN: First task should be cancelled
    #expect(task1.isCancelled)
    #expect(!firstCompleted)
  }

  @Test func executeTask_returnsTask() async {
    let sut = TaskManager()
    // WHEN: Execute a task
    let task = sut.executeTask(id: "test", operation: {}, onError: nil)

    // THEN: Should return a Task
    #expect(task is Task<Void, Never>)

    await task.value
  }

  @Test func executeTask_withEmptyStringId() async {
    let sut = TaskManager()
    // GIVEN & WHEN: Execute task with empty string ID
    var didExecute = false
    let task = sut.executeTask(id: "", operation: { didExecute = true }, onError: nil)

    await task.value

    // THEN: Should work normally
    #expect(didExecute)
  }

  // MARK: - cancelTasks(ids:)

  @Test func cancelTasks_cancelsSingleTask() async {
    let sut = TaskManager()
    // GIVEN: A running task
    let task = sut.executeTask(
      id: "internal", operation: { try await Task.sleep(nanoseconds: 100_000_000) }, onError: nil)

    // WHEN: Cancel using internal method with single ID in array
    sut.cancelTasks(ids: ["internal"])

    // THEN: Task should be cancelled immediately (synchronous)
    #expect(task.isCancelled)
  }

  @Test func cancelTasks_cancelsMultipleTasks() async {
    let sut = TaskManager()

    // GIVEN: Multiple running tasks (hold Task references)
    let task1 = sut.executeTask(
      id: "task-1", operation: { try await Task.sleep(nanoseconds: 100_000_000) }, onError: nil)
    let task2 = sut.executeTask(
      id: "task-2", operation: { try await Task.sleep(nanoseconds: 100_000_000) }, onError: nil)
    let task3 = sut.executeTask(
      id: "task-3", operation: { try await Task.sleep(nanoseconds: 100_000_000) }, onError: nil)

    // WHEN: Cancel multiple tasks at once
    sut.cancelTasks(ids: ["task-1", "task-3"])

    // THEN: Cancelled tasks are marked immediately (synchronous)
    #expect(task1.isCancelled)  // ✅ task-1 cancelled
    #expect(!task2.isCancelled)  // ✅ task-2 still running
    #expect(task3.isCancelled)  // ✅ task-3 cancelled
  }

  @Test func cancelTasks_withEmptyArray() async {
    let sut = TaskManager()
    // GIVEN: Running task
    let task = sut.executeTask(
      id: "task", operation: { try await Task.sleep(nanoseconds: 100_000_000) }, onError: nil)

    // WHEN: Cancel with empty array
    sut.cancelTasks(ids: [])

    // THEN: Task should not be affected
    #expect(!task.isCancelled)
  }

  @Test func cancelTasks_withNonExistentIds() async {
    let sut = TaskManager()
    // GIVEN: One running task
    let existingTask = sut.executeTask(
      id: "existing", operation: { try await Task.sleep(nanoseconds: 100_000_000) }, onError: nil)

    // WHEN: Cancel with non-existent IDs
    sut.cancelTasks(ids: ["non-existent-1", "non-existent-2"])

    // THEN: Should not crash, existing task should remain running
    #expect(!existingTask.isCancelled)
  }

  @Test func cancelTasks_withMixedExistingAndNonExistentIds() async {
    let sut = TaskManager()
    // GIVEN: Two running tasks
    let task1 = sut.executeTask(
      id: "task-1", operation: { try await Task.sleep(nanoseconds: 100_000_000) }, onError: nil)
    let task2 = sut.executeTask(
      id: "task-2", operation: { try await Task.sleep(nanoseconds: 100_000_000) }, onError: nil)

    // WHEN: Cancel with mix of existing and non-existent IDs
    sut.cancelTasks(ids: ["task-1", "non-existent", "task-2"])

    // THEN: Only existing tasks should be cancelled
    #expect(task1.isCancelled)
    #expect(task2.isCancelled)
  }

  @Test func cancelTasks_withDuplicateIds() async {
    let sut = TaskManager()
    // GIVEN: One running task
    let task = sut.executeTask(
      id: "dup", operation: { try await Task.sleep(nanoseconds: 100_000_000) }, onError: nil)

    // WHEN: Cancel with duplicate IDs in array
    sut.cancelTasks(ids: ["dup", "dup", "dup"])

    // THEN: Task should be cancelled only once (no crash)
    #expect(task.isCancelled)
  }

  // NOTE: TaskManager automatic task cleanup via isolated deinit is verified in integration tests
  // (e.g., TaskManagerIntegrationTests.automaticCancellationViaStoreDeinit)
  // Direct weak reference checks in unit tests are unreliable due to:
  // - isolated deinit's async execution on MainActor
  // - Swift Testing framework's potential reference retention
}
