// swiftlint:disable file_length
import Foundation
import Testing

@testable import Flow

// MARK: - Test Fixtures

enum SaveResult: Sendable, Equatable {
  case created(id: String)
  case updated
  case deleted
  case noChange
}

enum SaveAction: Sendable {
  case create(String)
  case update(String)
  case delete
  case noop
}

@Observable
final class SaveState {
  var lastOperation: String?

  init(lastOperation: String? = nil) {
    self.lastOperation = lastOperation
  }
}

struct SaveFeature: Feature, Sendable {
  func handle() -> ActionHandler<SaveAction, SaveState, SaveResult> {
    ActionHandler { action, state in
      switch action {
      case .create(let id):
        state.lastOperation = "create"
        return .just(.created(id: id))

      case .update:
        state.lastOperation = "update"
        return .just(.updated)

      case .delete:
        state.lastOperation = "delete"
        return .just(.deleted)

      case .noop:
        state.lastOperation = "noop"
        return .just(.noChange)
      }
    }
  }
}

enum ConcatAction: Sendable {
  case multiStep
  case allNone
  case mixedResults
}

@Observable
final class ConcatState {
  var steps: [String] = []

  init(steps: [String] = []) {
    self.steps = steps
  }
}

struct ConcatFeature: Feature, Sendable {
  func handle() -> ActionHandler<ConcatAction, ConcatState, SaveResult> {
    ActionHandler { action, state in
      switch action {
      case .multiStep:
        // Test: .result, .result, .result pattern
        // Return last meaningful result
        state.steps.append("step1")
        return .concatenate(
          .just(.created(id: "first")),
          .just(.updated),
          .just(.created(id: "final"))
        )

      case .allNone:
        // Test: single result
        return .just(.noChange)

      case .mixedResults:
        // Test: multiple .just() in concatenate
        state.steps.append("middle")
        return .concatenate(
          .just(.created(id: "first")),
          .just(.updated)  // This should be the final result
        )
      }
    }
  }
}

@Observable
final class InferredState {
  var value = 0
  init() {}
}

enum InferredAction: Sendable {
  case test
}

struct InferredFeature: Feature, Sendable {
  // ActionResult is inferred as String from return type
  func handle() -> ActionHandler<InferredAction, InferredState, String> {
    ActionHandler { _, state in
      state.value = 42
      return .just("inferred-type")
    }
  }
}

@Observable
final class AsyncState {
  var isLoading = false
  init() {}
}

enum AsyncAction: Sendable {
  case fetchUser
}

struct AsyncFeature: Feature, Sendable {
  func handle() -> ActionHandler<AsyncAction, AsyncState, String> {
    ActionHandler { _, state in
      state.isLoading = true
      return .run { state in
        // Simulate async work
        try await Task.sleep(for: .milliseconds(10))
        state.isLoading = false
        return "user-id-789"
      }
    }
  }
}

@Observable
final class QuickFailState {
  var completed = false
  init() {}
}

enum QuickFailAction: Sendable {
  case fail
}

struct QuickFailFeature: Feature, Sendable {
  func handle() -> ActionHandler<QuickFailAction, QuickFailState, Void> {
    ActionHandler { action, _ in
      switch action {
      case .fail:
        return .run { _ in
          throw NSError(domain: "Immediate", code: 1)
        }
      }
    }
  }
}

// Error handling test fixtures
@Observable
final class DoCatchState {
  var attemptCount = 0
  init() {}
}

enum DoCatchAction: Sendable {
  case tryOperation
  case tryWithFallback
  case tryWithRethrow
}

struct DoCatchFeature: Feature, Sendable {
  func handle() -> ActionHandler<DoCatchAction, DoCatchState, SaveResult> {
    ActionHandler { action, state in
      switch action {
      case .tryOperation:
        // Pattern 1: do-catch converts error to success with different result
        return .run { state in
          state.attemptCount += 1
          do {
            // Simulate an error
            throw NSError(domain: "API", code: 500)
            // Would have returned: .created(id: "123")
          } catch {
            // ✅ Catch error and return different success result
            return .noChange
          }
        }

      case .tryWithFallback:
        // Pattern 2: try multiple operations, fallback on error
        return .run { state in
          state.attemptCount += 1
          do {
            // Primary operation fails
            throw NSError(domain: "Primary", code: 1)
          } catch {
            // Fallback: try alternative approach
            do {
              // Alternative also fails
              throw NSError(domain: "Alternative", code: 2)
            } catch {
              // Ultimate fallback: return safe result
              return .updated
            }
          }
        }

      case .tryWithRethrow:
        // Pattern 3: catch, log, then re-throw
        return .run { state in
          state.attemptCount += 1
          do {
            throw NSError(domain: "Critical", code: 999)
          } catch {
            // Log or update state, then re-throw
            state.attemptCount += 100  // Mark as critical error
            throw error  // Re-throw to caller
          }
        }
      }
    }
  }
}

@Observable
final class VoidReturnState {
  var counter = 0
  init() {}
}

enum VoidReturnAction: Sendable {
  case increment
  case asyncIncrement
}

struct VoidReturnFeature: Feature, Sendable {
  func handle() -> ActionHandler<VoidReturnAction, VoidReturnState, Void> {
    ActionHandler { action, state in
      switch action {
      case .increment:
        state.counter += 1
        return .none

      case .asyncIncrement:
        return .run { state in
          // ✅ No explicit return needed for Void
          state.counter += 1
          // Implicit return ()
        }
      }
    }
  }
}

@Observable
final class NonVoidReturnState {
  var processed = false
  init() {}
}

enum NonVoidReturnAction: Sendable {
  case process
}

struct NonVoidReturnFeature: Feature, Sendable {
  func handle() -> ActionHandler<NonVoidReturnAction, NonVoidReturnState, SaveResult> {
    ActionHandler { action, state in
      switch action {
      case .process:
        return .run { state in
          state.processed = true
          // ✅ Return ActionResult directly
          return .updated
        }
      }
    }
  }
}

@Observable
final class DirectReturnState {
  var value = 0
  init() {}
}

enum DirectReturnAction: Sendable {
  case compute
}

struct DirectReturnFeature: Feature, Sendable {
  func handle() -> ActionHandler<DirectReturnAction, DirectReturnState, SaveResult> {
    ActionHandler { action, state in
      switch action {
      case .compute:
        return .run { state in
          state.value = 42
          // ✅ Return ActionResult directly (SaveResult)
          return .created(id: "direct-123")
        }
      }
    }
  }
}

@Observable
final class HybridState {
  var internalCatchCalled = false
  var externalCatchCalled = false
  init() {}
}

enum HybridAction: Sendable {
  case hybrid
}

struct HybridFeature: Feature, Sendable {
  func handle() -> ActionHandler<HybridAction, HybridState, Void> {
    ActionHandler { action, state in
      switch action {
      case .hybrid:
        return .run { state in
          do {
            throw NSError(domain: "Internal", code: 1)
          } catch {
            // Internal catch
            state.internalCatchCalled = true
            // Re-throw for external catch
            throw error
          }
        }
        .catch { _, state in
          // External catch
          state.externalCatchCalled = true
        }
      }
    }
  }
}

@Observable
final class ErrorState {
  var callCount = 0
  init() {}
}

enum ErrorAction: Sendable {
  case failingAction
}

struct ErrorFeature: Feature, Sendable {
  func handle() -> ActionHandler<ErrorAction, ErrorState, Void> {
    ActionHandler { action, state in
      switch action {
      case .failingAction:
        state.callCount += 1
        return .run { _ in
          throw NSError(
            domain: "TestError", code: 42,
            userInfo: [
              NSLocalizedDescriptionKey: "Test error message"
            ])
        }
      }
    }
  }
}

@Observable
final class CatchState {
  var errorMessage: String?
  var errorHandlerCalled = false
  init() {}
}

enum CatchAction: Sendable {
  case failingAction
}

struct CatchFeature: Feature, Sendable {
  func handle() -> ActionHandler<CatchAction, CatchState, Void> {
    ActionHandler { action, state in
      switch action {
      case .failingAction:
        return .run { _ in
          throw NSError(domain: "API", code: 500)
        }
        .catch { error, state in
          state.errorMessage = "Caught: \(error.localizedDescription)"
          state.errorHandlerCalled = true
        }
      }
    }
  }
}

@Observable
final class FailingSaveState {
  var errorLogged: String?
  init() {}
}

enum FailingSaveAction: Sendable {
  case save(String)
}

struct FailingSaveFeature: Feature, Sendable {
  func handle() -> ActionHandler<FailingSaveAction, FailingSaveState, SaveResult> {
    ActionHandler { action, state in
      switch action {
      case .save:
        return .run { _ in
          throw NSError(
            domain: "Network", code: -1009,
            userInfo: [
              NSLocalizedDescriptionKey: "Network connection lost"
            ])
        }
        .catch { error, state in
          state.errorLogged = error.localizedDescription
        }
      }
    }
  }
}

// Large data performance test fixtures
@Observable
final class LargeDataState {
  init() {}
}

enum LargeDataAction: Sendable {
  case fetchLarge
}

struct LargeDataFeature: Feature, Sendable {
  func handle() -> ActionHandler<LargeDataAction, LargeDataState, String> {
    ActionHandler { _, _ in
      // Create ~100KB string
      let largeString = String(repeating: "x", count: 100_000)
      return .just(largeString)
    }
  }
}

// MARK: - Tests

/// Comprehensive tests for ActionResult functionality.
///
/// Tests the new features added in the recent refactoring:
/// - `.just(_:)` method for returning result values
/// - `concatenate` with ActionResult != Void
/// - Type inference for ActionResult
@MainActor
@Suite struct ActionResultTests {
  // MARK: - .just(_:) Tests

  @Test func result_returnsCreatedValue() async {
    // GIVEN: Store with ActionResult != Void
    let store = Store(
      initialState: SaveState(),
      feature: SaveFeature()
    )

    // WHEN: Send action that returns .just(.created)
    let result = await store.send(.create("test-id-123")).value

    // THEN: Should return the created result with correct ID
    switch result {
    case .success(.created(let id)):
      #expect(id == "test-id-123")
      #expect(store.state.lastOperation == "create")
    case .success:
      Issue.record("Expected .created result")
    case .failure(let error):
      Issue.record("Should not fail: \(error)")
    }
  }

  @Test func result_returnsUpdatedValue() async {
    // GIVEN: Store with SaveFeature
    let store = Store(
      initialState: SaveState(),
      feature: SaveFeature()
    )

    // WHEN: Send update action
    let result = await store.send(.update("item-456")).value

    // THEN: Should return .updated
    switch result {
    case .success(.updated):
      #expect(store.state.lastOperation == "update")
    case .success:
      Issue.record("Expected .updated result")
    case .failure(let error):
      Issue.record("Should not fail: \(error)")
    }
  }

  @Test func result_returnsDeletedValue() async {
    // GIVEN: Store with SaveFeature
    let store = Store(
      initialState: SaveState(),
      feature: SaveFeature()
    )

    // WHEN: Send delete action
    let result = await store.send(.delete).value

    // THEN: Should return .deleted
    switch result {
    case .success(.deleted):
      #expect(store.state.lastOperation == "delete")
    case .success:
      Issue.record("Expected .deleted result")
    case .failure(let error):
      Issue.record("Should not fail: \(error)")
    }
  }

  @Test func result_returnsNoChangeValue() async {
    // GIVEN: Store with SaveFeature
    let store = Store(
      initialState: SaveState(),
      feature: SaveFeature()
    )

    // WHEN: Send noop action
    let result = await store.send(.noop).value

    // THEN: Should return .noChange
    switch result {
    case .success(.noChange):
      #expect(store.state.lastOperation == "noop")
    case .success:
      Issue.record("Expected .noChange result")
    case .failure(let error):
      Issue.record("Should not fail: \(error)")
    }
  }

  // MARK: - concatenate + ActionResult Tests

  @Test func concatenate_returnsLastMeaningfulResult() async {
    // GIVEN: Feature with concatenate of multiple .just()
    let store = Store(
      initialState: ConcatState(),
      feature: ConcatFeature()
    )

    // WHEN: Execute concatenated tasks
    let result = await store.send(.multiStep).value

    // THEN: Should return the last .just() value
    switch result {
    case .success(.created(let id)):
      #expect(id == "final")
      #expect(store.state.steps == ["step1"])
    case .success:
      Issue.record("Expected .created(id: 'final') result")
    case .failure(let error):
      Issue.record("Should not fail: \(error)")
    }
  }

  @Test func concatenate_withMultipleResults_returnsLast() async {
    // GIVEN: Feature with multiple .just() calls
    let store = Store(
      initialState: ConcatState(),
      feature: ConcatFeature()
    )

    // WHEN: Execute concatenate with multiple results
    let result = await store.send(.mixedResults).value

    // THEN: Should return the last .just() value
    switch result {
    case .success(.updated):
      #expect(store.state.steps == ["middle"])
    case .success:
      Issue.record("Expected .updated result (last one)")
    case .failure(let error):
      Issue.record("Should not fail: \(error)")
    }
  }

  // MARK: - Type Inference Tests

  @Test func typeInference_fromHandleReturnType() async {
    // GIVEN: Feature with String result type
    let store = Store(
      initialState: InferredState(),
      feature: InferredFeature()
    )

    // WHEN: Send action
    let result = await store.send(.test).value

    // THEN: Type should be inferred correctly
    switch result {
    case .success(let value):
      #expect(value == "inferred-type")
      #expect(store.state.value == 42)
    case .failure(let error):
      Issue.record("Should not fail: \(error)")
    }
  }

  @Test func typeInference_voidIsInferred() async {
    // GIVEN: Feature using shared CounterState from TestFixtures
    // This demonstrates that ActionResult = Void is inferred automatically
    let store = Store(
      initialState: CounterState(),
      feature: CounterFeature()
    )

    // WHEN: Send action
    let result = await store.send(.increment).value

    // THEN: Void type should be inferred
    switch result {
    case .success:
      #expect(store.state.count == 1)
    case .failure(let error):
      Issue.record("Should not fail: \(error)")
    }
  }

  // MARK: - Integration Tests

  @Test func result_withAsyncOperation() async {
    // GIVEN: Feature with async operation returning result
    let store = Store(
      initialState: AsyncState(),
      feature: AsyncFeature()
    )

    // WHEN: Send async action and await result
    let result = await store.send(.fetchUser).value

    // THEN: Should complete and return result
    switch result {
    case .success(let userId):
      #expect(userId == "user-id-789")
      #expect(store.state.isLoading == false)
    case .failure(let error):
      Issue.record("Should not fail: \(error)")
    }
  }

  @Test func result_sequentialActions() async {
    // GIVEN: Store that returns results
    let store = Store(
      initialState: SaveState(),
      feature: SaveFeature()
    )

    // WHEN: Send multiple actions sequentially
    let result1 = await store.send(.create("id-1")).value
    let result2 = await store.send(.update("id-2")).value
    let result3 = await store.send(.delete).value

    // THEN: Each should return correct result
    switch result1 {
    case .success(.created(let id)):
      #expect(id == "id-1")
    default:
      Issue.record("Expected .created")
    }

    switch result2 {
    case .success(.updated):
      #expect(Bool(true))
    default:
      Issue.record("Expected .updated")
    }

    switch result3 {
    case .success(.deleted):
      #expect(Bool(true))
    default:
      Issue.record("Expected .deleted")
    }
  }

  // MARK: - Error Handling with Result Tests

  /// Verify that errors are returned as Result.failure, not lost
  @Test func errorHandling_returnsFailureResult() async {
    // GIVEN: Feature that throws an error
    let store = Store(
      initialState: ErrorState(),
      feature: ErrorFeature()
    )

    // WHEN: Send action that throws error
    let result = await store.send(.failingAction).value

    // THEN: Result should be .failure (not lost!)
    switch result {
    case .success:
      Issue.record("Expected .failure but got .success")
    case .failure(let error as NSError):
      #expect(error.domain == "TestError")
      #expect(error.code == 42)
      #expect(error.localizedDescription.contains("Test error message"))
    case .failure(let error):
      Issue.record("Unexpected error type: \(error)")
    }

    // AND: State mutation before error should be preserved
    #expect(store.state.callCount == 1)
  }

  /// Verify that .catch() updates state but still returns Result.failure
  @Test func errorHandling_withCatch_stillReturnsFailure() async {
    // GIVEN: Feature with .catch() error handler
    let store = Store(
      initialState: CatchState(),
      feature: CatchFeature()
    )

    // WHEN: Send action with .catch() handler
    let result = await store.send(.failingAction).value

    // THEN: Result should still be .failure (error not suppressed)
    switch result {
    case .success:
      Issue.record("Expected .failure even with .catch()")
    case .failure(let error as NSError):
      #expect(error.domain == "API")
      #expect(error.code == 500)
    case .failure:
      Issue.record("Unexpected error type")
    }

    // AND: .catch() handler should have updated state
    #expect(store.state.errorHandlerCalled)
    #expect(store.state.errorMessage?.contains("Caught") ?? false)
  }

  /// Verify that custom ActionResult types also return Result.failure on error
  @Test func errorHandling_customResultType_returnsFailure() async {
    // GIVEN: Feature with custom ActionResult that can fail
    let store = Store(
      initialState: FailingSaveState(),
      feature: FailingSaveFeature()
    )

    // WHEN: Send action that should return SaveResult but throws
    let result = await store.send(.save("data")).value

    // THEN: Result should be .failure, not .success(SaveResult)
    switch result {
    case .success(.created(let id)):
      Issue.record("Expected .failure but got .success(.created(\(id)))")
    case .success(.updated):
      Issue.record("Expected .failure but got .success(.updated)")
    case .success:
      Issue.record("Expected .failure but got .success")
    case .failure(let error as NSError):
      #expect(error.domain == "Network")
      #expect(error.code == -1009)
      #expect(error.localizedDescription.contains("Network connection lost"))
    case .failure(let error):
      Issue.record("Unexpected error type: \(error)")
    }

    // AND: Error was logged via .catch()
    #expect(store.state.errorLogged?.contains("Network connection lost") ?? false)
  }

  /// Verify that Result is always returned, never hangs
  @Test func errorHandling_alwaysReturnsResult() async {
    // GIVEN: Store that might hang if error handling is broken
    let store = Store(
      initialState: QuickFailState(),
      feature: QuickFailFeature()
    )

    // WHEN: Send failing action
    // This should complete quickly, not hang indefinitely
    let result = await store.send(.fail).value

    // THEN: Result should be returned (test passes = no hang)
    switch result {
    case .success:
      Issue.record("Expected .failure")
    case .failure:
      #expect(Bool(true))  // Success: we got a result
    }
  }

  // MARK: - do-catch Pattern Tests

  /// Verify that do-catch inside .run can convert error to success
  @Test func doCatch_convertsErrorToSuccess() async {
    // GIVEN: Feature that catches error and returns success result
    let store = Store(
      initialState: DoCatchState(),
      feature: DoCatchFeature()
    )

    // WHEN: Send action that throws but catches internally
    let result = await store.send(.tryOperation).value

    // THEN: Result should be .success (error was caught and converted)
    switch result {
    case .success(.noChange):
      #expect(Bool(true))  // ✅ Error converted to success!
      #expect(store.state.attemptCount == 1)
    case .success(let other):
      Issue.record("Expected .noChange but got \(other)")
    case .failure(let error):
      Issue.record("Expected .success but got .failure: \(error)")
    }
  }

  /// Verify that do-catch can implement fallback logic
  @Test func doCatch_implementsFallbackLogic() async {
    // GIVEN: Feature with nested fallback logic
    let store = Store(
      initialState: DoCatchState(),
      feature: DoCatchFeature()
    )

    // WHEN: Send action with fallback pattern
    let result = await store.send(.tryWithFallback).value

    // THEN: Should return fallback result after multiple failures
    switch result {
    case .success(.updated):
      #expect(Bool(true))  // ✅ Fallback worked!
      #expect(store.state.attemptCount == 1)
    case .success(let other):
      Issue.record("Expected .updated but got \(other)")
    case .failure(let error):
      Issue.record("Expected .success but got .failure: \(error)")
    }
  }

  /// Verify that do-catch can re-throw after logging
  @Test func doCatch_canRethrowAfterLogging() async {
    // GIVEN: Feature that catches, logs, then re-throws
    let store = Store(
      initialState: DoCatchState(),
      feature: DoCatchFeature()
    )

    // WHEN: Send action that re-throws
    let result = await store.send(.tryWithRethrow).value

    // THEN: Result should be .failure (error was re-thrown)
    switch result {
    case .success(let res):
      Issue.record("Expected .failure but got .success(\(res))")
    case .failure(let error as NSError):
      #expect(error.domain == "Critical")
      #expect(error.code == 999)
      // AND: State was updated before re-throw
      #expect(store.state.attemptCount == 101)  // 1 + 100
    case .failure(let error):
      Issue.record("Unexpected error type: \(error)")
    }
  }

  // MARK: - Return Omission Tests

  /// Verify that ActionHandler (Void result) can omit return in .run
  @Test func voidResult_canOmitReturn() async {
    // GIVEN: ActionHandler that omits return in .run block
    let store = Store(
      initialState: VoidReturnState(),
      feature: VoidReturnFeature()
    )

    // WHEN: Send async action with omitted return
    let result = await store.send(.asyncIncrement).value

    // THEN: Should succeed without explicit return
    switch result {
    case .success:
      #expect(store.state.counter == 1)
    case .failure(let error):
      Issue.record("Should not fail: \(error)")
    }
  }

  /// Verify that ActionHandler can return ActionResult directly
  @Test func nonVoidResult_canReturnDirectly() async {
    // GIVEN: ActionHandler that returns SaveResult directly
    let store = Store(
      initialState: NonVoidReturnState(),
      feature: NonVoidReturnFeature()
    )

    // WHEN: Send action
    let result = await store.send(.process).value

    // THEN: Should return the ActionResult directly (no .just() wrapper needed)
    switch result {
    case .success(.updated):
      #expect(store.state.processed)
    case .success(let other):
      Issue.record("Expected .updated but got \(other)")
    case .failure(let error):
      Issue.record("Should not fail: \(error)")
    }
  }

  /// Verify that .run returns ActionResult type directly, not wrapped
  @Test func runBlock_returnsActionResultDirectly() async {
    // GIVEN: Feature demonstrating direct ActionResult return
    let store = Store(
      initialState: DirectReturnState(),
      feature: DirectReturnFeature()
    )

    // WHEN: Send action
    let result = await store.send(.compute).value

    // THEN: ActionResult is returned directly
    switch result {
    case .success(.created(let id)):
      #expect(id == "direct-123")
      #expect(store.state.value == 42)
    case .success(let other):
      Issue.record("Expected .created but got \(other)")
    case .failure(let error):
      Issue.record("Should not fail: \(error)")
    }
  }

  /// Verify that .catch() and internal do-catch can work together
  @Test func doCatch_withExternalCatch() async {
    // GIVEN: Feature with both internal do-catch and external .catch()
    let store = Store(
      initialState: HybridState(),
      feature: HybridFeature()
    )

    // WHEN: Send hybrid action
    let result = await store.send(.hybrid).value

    // THEN: Both catches should be called
    #expect(store.state.internalCatchCalled)
    #expect(store.state.externalCatchCalled)

    // AND: Result should still be .failure
    switch result {
    case .success:
      Issue.record("Expected .failure")
    case .failure:
      #expect(Bool(true))
    }
  }

  // MARK: - Concurrency Edge Cases

  /// Verify that multiple stores can send actions simultaneously with independent results
  @Test func concurrency_multipleStoresSimultaneousSend_independentResults() async {
    // GIVEN: Two independent stores
    let store1 = Store(
      initialState: SaveState(),
      feature: SaveFeature()
    )
    let store2 = Store(
      initialState: SaveState(),
      feature: SaveFeature()
    )

    // WHEN: Send different actions to each store simultaneously
    async let result1 = store1.send(.create("store1-id")).value
    async let result2 = store2.send(.update("store2-id")).value

    let (r1, r2) = await (result1, result2)

    // THEN: Each store should return its own result independently
    switch r1 {
    case .success(.created(let id)):
      #expect(id == "store1-id")
    case .success(let other):
      Issue.record("Store1 expected .created but got \(other)")
    case .failure(let error):
      Issue.record("Store1 should not fail: \(error)")
    }

    switch r2 {
    case .success(.updated):
      #expect(store2.state.lastOperation == "update")
    case .success(let other):
      Issue.record("Store2 expected .updated but got \(other)")
    case .failure(let error):
      Issue.record("Store2 should not fail: \(error)")
    }

    // AND: Stores should have independent state
    #expect(store1.state.lastOperation == "create")
    #expect(store2.state.lastOperation == "update")
  }

  /// Verify rapid sequential actions return correct results
  @Test func concurrency_rapidSequentialActions_allResultsCorrect() async {
    // GIVEN: Store that returns different results per action
    let store = Store(
      initialState: SaveState(),
      feature: SaveFeature()
    )

    // WHEN: Send multiple actions rapidly
    let result1 = await store.send(.create("first")).value
    let result2 = await store.send(.update("second")).value
    let result3 = await store.send(.delete).value
    let result4 = await store.send(.noop).value

    // THEN: All results should be correct in order
    var results: [SaveResult] = []

    switch result1 {
    case .success(let res): results.append(res)
    case .failure(let error): Issue.record("Action 1 failed: \(error)")
    }

    switch result2 {
    case .success(let res): results.append(res)
    case .failure(let error): Issue.record("Action 2 failed: \(error)")
    }

    switch result3 {
    case .success(let res): results.append(res)
    case .failure(let error): Issue.record("Action 3 failed: \(error)")
    }

    switch result4 {
    case .success(let res): results.append(res)
    case .failure(let error): Issue.record("Action 4 failed: \(error)")
    }

    // Verify all results match expected sequence
    #expect(results.count == 4)
    if results.count == 4 {
      #expect(results[0] == .created(id: "first"))
      #expect(results[1] == .updated)
      #expect(results[2] == .deleted)
      #expect(results[3] == .noChange)
    }
  }

  // MARK: - Performance Tests

  /// Verify that large result payloads don't cause performance issues
  @Test func performance_largeResultPayload_acceptable() async {
    // GIVEN: Feature that returns large data as result
    let store = Store(
      initialState: LargeDataState(),
      feature: LargeDataFeature()
    )

    // WHEN: Send action and measure time
    let start = Date()
    let result = await store.send(.fetchLarge).value
    let duration = Date().timeIntervalSince(start)

    // THEN: Should complete quickly
    // iOS Simulator is significantly slower than native macOS due to virtualization overhead
    #if targetEnvironment(simulator)
      let timeout: TimeInterval = 3.0  // iOS Simulator: allow 3.0s
    #else
      let timeout: TimeInterval = 0.5  // Native: expect < 500ms
    #endif
    #expect(duration < timeout)

    switch result {
    case .success(let data):
      #expect(data.count == 100_000)
    case .failure(let error):
      Issue.record("Should not fail: \(error)")
    }
  }

  /// Verify that many sequential results maintain good performance
  @Test func performance_manySequentialResults_acceptable() async {
    // GIVEN: Store with simple feature
    let store = Store(
      initialState: SaveState(),
      feature: SaveFeature()
    )

    // WHEN: Send 100 actions sequentially
    let start = Date()

    for index in 0..<100 {
      let result = await store.send(.create("id-\(index)")).value

      switch result {
      case .success(.created(let id)):
        #expect(id == "id-\(index)")
      case .success(let other):
        Issue.record("Expected .created but got \(other)")
      case .failure(let error):
        Issue.record("Should not fail: \(error)")
      }
    }

    let duration = Date().timeIntervalSince(start)

    // THEN: Should complete in reasonable time
    // iOS Simulator is significantly slower than native macOS due to virtualization overhead
    #if targetEnvironment(simulator)
      let timeout: TimeInterval = 7.0  // iOS Simulator: allow 7s for 100 actions
    #else
      let timeout: TimeInterval = 1.5  // Native: expect < 1.5s for 100 actions
    #endif
    #expect(duration < timeout)
  }
}
