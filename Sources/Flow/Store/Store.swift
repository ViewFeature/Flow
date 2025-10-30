import Foundation
import Observation

/// Errors that can occur during Store operations.
public enum StoreError: Error, Sendable {
  /// The store was deallocated before the operation could complete
  case deallocated
  /// The operation was cancelled
  case cancelled
}

/// The main store for managing application state and dispatching actions.
///
/// `Store` provides a Redux-like unidirectional data flow architecture for SwiftUI apps
/// with fire-and-forget action dispatching and MainActor-isolated state management.
///
/// ## Key Characteristics
/// - **MainActor Isolation**: All state mutations occur on the MainActor for thread-safe UI updates
/// - **Fire-and-Forget API**: Actions can be dispatched without awaiting, or awaited when needed
/// - **Sequential Processing**: Actions are processed sequentially to ensure state consistency
///
/// The Store coordinates between state management, action processing, and task execution while
/// maintaining the Single Responsibility Principle by delegating to specialized components.
///
/// ## Example Usage
/// ```swift
/// struct AppFeature: Feature {
///     @Observable
///     final class State {
///         var count: Int = 0
///
///         init(count: Int = 0) {
///             self.count = count
///         }
///     }
///
///     enum Action: Sendable {
///         case increment
///         case decrement
///     }
///
///     func handle() -> ActionHandler<Action, State, Void> {
///         ActionHandler { action, state in
///             switch action {
///             case .increment:
///                 state.count += 1
///             case .decrement:
///                 state.count -= 1
///             }
///             return .none
///         }
///     }
/// }
///
/// // Use in SwiftUI with @State
/// struct ContentView: View {
///     @State private var store = Store(
///         initialState: AppFeature.State(),
///         feature: AppFeature()
///     )
///
///     var body: some View {
///         VStack {
///             Text("Count: \(store.state.count)")
///             Button("Increment") {
///                 store.send(.increment)
///             }
///         }
///     }
/// }
/// ```
///
/// - Important: Always use `@State` to hold the Store in SwiftUI Views to maintain
///   the store instance across view updates and prevent unnecessary re-initialization.
///
/// ## Topics
/// ### Creating a Store
/// - ``init(initialState:feature:taskManager:)``
///
/// ### Accessing State
/// - ``state``
///
/// ### Dispatching Actions
/// - ``send(_:)``
@Observable
@MainActor
public final class Store<F: Feature> {
  private var _state: F.State
  private let taskManager: TaskManager
  private let handler: ActionHandler<F.Action, F.State, F.ActionResult>

  /// The current state of the feature.
  ///
  /// The Store is @Observable, so accessing this property from SwiftUI views enables
  /// automatic updates when state changes. Access this property from your views to
  /// read the current state.
  public var state: F.State {
    _state
  }

  // MARK: - Initialization

  /// Primary initializer with full DIP compliance
  public init(
    initialState: F.State,
    feature: F,
    taskManager: TaskManager = TaskManager()
  ) {
    self._state = initialState
    self.taskManager = taskManager
    self.handler = feature.handle()
  }

  // MARK: - Action Dispatch API

  /// Dispatches an action and processes it through the handler using a fire-and-forget pattern.
  ///
  /// This method provides flexible action dispatching:
  /// - **Fire-and-forget**: Call without awaiting for non-blocking UI operations
  /// - **Await completion**: Use `await store.send(...).value` when you need to wait
  /// - **Cancellable**: Cancel the returned Task to stop action processing
  ///
  /// All action processing occurs on the **MainActor**, ensuring thread-safe state mutations
  /// and seamless integration with SwiftUI.
  ///
  /// - Parameter action: The action to dispatch
  /// - Returns: A Task that completes when the action processing finishes.
  ///   You can await or cancel this task as needed.
  ///
  /// ## Fire-and-Forget Pattern
  /// ```swift
  /// // Fire-and-forget: Non-blocking, perfect for UI interactions
  /// Button("Increment") {
  ///   store.send(.increment)  // Returns immediately
  /// }
  ///
  /// // Wait for completion: Useful for testing or ensuring side effects complete
  /// await store.send(.loadData).value  // Waits until data is loaded
  /// ```
  ///
  /// ## Task Cancellation
  /// You can cancel action processing by cancelling the returned Task:
  /// ```swift
  /// let task = store.send(.longRunningTask)
  /// task.cancel()  // Stops the task if it hasn't completed
  /// ```
  ///
  /// ## MainActor Execution
  /// All actions and state mutations execute on the **MainActor**:
  /// ```swift
  /// // This action handler runs on MainActor
  /// ActionHandler { action, state in
  ///   switch action {
  ///   case .increment:
  ///     state.count += 1  // ✅ Safe MainActor mutation
  ///     return .none
  ///   }
  /// }
  /// ```
  ///
  /// ## Sequential Processing
  /// Actions are processed **sequentially** on the MainActor. If an action returns
  /// a `.run` task, the Store will await its completion before processing the next action.
  ///
  /// ```swift
  /// store.send(.longRunningTask)  // Takes 5 seconds
  /// store.send(.quickTask)        // Waits until longRunningTask completes
  /// ```
  ///
  /// **Why sequential?**
  /// - Ensures state consistency (no concurrent mutations)
  /// - Simplifies reasoning about action order
  /// - Prevents race conditions
  ///
  /// If you need truly concurrent background work, dispatch it inside the `.run` block:
  /// ```swift
  /// return .run { state in
  ///   // Fire-and-forget background work
  ///   Task.detached {
  ///     await heavyBackgroundWork()
  ///   }
  ///   // This returns immediately
  /// }
  /// ```
  @discardableResult
  public func send(_ action: F.Action) -> Task<Result<F.ActionResult, Error>, Never> {
    Task { @MainActor [weak self] in
      guard let self else {
        return .failure(StoreError.deallocated)
      }

      do {
        let result = try await self.processAction(action)
        return .success(result)
      } catch {
        return .failure(error)
      }
    }
  }

  // MARK: - Private Implementation

  /// Executes a .run task with the TaskManager.
  ///
  /// This helper method handles the complexity of executing async operations,
  /// managing task cancellation, and error handling.
  // swiftlint:disable:next function_parameter_count
  private func executeRunTask(
    id: String,
    name: String?,
    operation: @escaping @MainActor (F.State) async throws -> F.ActionResult,
    onError: (@MainActor (Error, F.State) -> Void)?,
    cancelInFlight: Bool,
    priority: TaskPriority?
  ) async throws -> F.ActionResult {
    if cancelInFlight {
      taskManager.cancelTasks(ids: [id])
    }

    var taskResult: F.ActionResult?
    var taskError: Error?

    let runningTask = taskManager.executeTask(
      id: id,
      name: name,
      operation: { @MainActor [weak self] in
        guard let self else {
          throw StoreError.deallocated
        }

        // Check for cancellation before executing operation
        try Task.checkCancellation()

        let result = try await operation(self._state)
        taskResult = result
      },
      onError: { @MainActor [weak self] (error: Error) in
        guard let self else { return }
        // Always capture error for re-throwing
        taskError = error
        // Call user's error handler if provided
        onError?(error, self._state)
      },
      priority: priority
    )

    // Await task completion for sequential processing (see send() documentation)
    await runningTask.value

    if let error = taskError {
      throw error
    }

    guard let result = taskResult else {
      throw StoreError.cancelled
    }

    return result
  }

  /// Processes an action sequentially with cancellation support.
  ///
  /// This method checks for task cancellation at key points to ensure
  /// cancellation propagates through the action processing pipeline.
  private func processAction(_ action: F.Action) async throws -> F.ActionResult {
    // Check if the parent task was cancelled before starting
    guard !Task.isCancelled else {
      throw StoreError.cancelled
    }

    let actionTask = await handler.handle(action: action, state: _state)

    // Check again before executing the task
    guard !Task.isCancelled else {
      throw StoreError.cancelled
    }

    return try await executeTask(actionTask)
  }

  /// Executes an ActionTask with cancellation propagation support and returns the result.
  ///
  /// This method ensures that task cancellation propagates correctly through
  /// all task types (run, cancel, concatenate).
  ///
  /// ## Design Decision: Why Not Extract to TaskExecutor?
  ///
  /// This method remains in Store rather than being extracted to a separate TaskExecutor for these reasons:
  ///
  /// 1. **Natural Responsibility**: Store's core responsibility is orchestrating the flow from Action → State.
  ///    The `executeTask()` method selects execution strategies (sequential, cancellation),
  ///    which is orchestration, not low-level execution. Low-level execution is already delegated to TaskManager.
  ///
  /// 2. **Simplicity**: Each case is concise (1-10 lines) and delegates actual work to TaskManager or Swift's
  ///    structured concurrency primitives. Adding a TaskExecutor layer would introduce
  ///    unnecessary indirection without meaningful separation of concerns.
  ///
  /// 3. **Industry Standard**: This follows the same pattern as The Composable Architecture (TCA),
  ///    where the Store handles effect execution strategy while delegating to lower-level primitives.
  ///
  /// 4. **Avoids Over-Engineering**: A TaskExecutor would create ambiguity with TaskManager and add
  ///    complexity (Store → TaskExecutor → TaskManager) without clear benefit.
  ///
  /// The current design strikes the right balance: Store orchestrates, TaskManager executes.
  private func executeTask(_ task: ActionTask<F.Action, F.State, F.ActionResult>) async throws
    -> F.ActionResult {
    // Check for cancellation before executing
    guard !Task.isCancelled else {
      throw StoreError.cancelled
    }

    switch task.operation {
    case .just(let result):
      return result

    case .run(let id, let name, let operation, let onError, let cancelInFlight, let priority):
      return try await executeRunTask(
        id: id,
        name: name,
        operation: operation,
        onError: onError,
        cancelInFlight: cancelInFlight,
        priority: priority
      )

    case .cancel(let ids, let result):
      taskManager.cancelTasks(ids: ids)
      return result

    case .concatenated:
      // Flatten concatenate tree for sequential iteration (O(n) → O(1) depth)
      let tasks = task.flattenConcatenated()

      // INVARIANT: flattenConcatenated() always returns ≥1 element
      //
      // Proof:
      // 1. concatenate([]) now throws FlowError.noTasksToExecute
      // 2. .concatenated can only be constructed via concatenate()
      // 3. Therefore, .concatenated always contains ≥1 task
      // 4. flattenConcatenated() preserves this property
      //
      // If this precondition fails, there's a bug in ActionTask construction
      precondition(!tasks.isEmpty, "Implementation error: concatenated task list is empty. This should be impossible due to concatenate() throwing on empty arrays.")

      var lastResult: F.ActionResult = try await self.executeTask(tasks[0])

      for task in tasks.dropFirst() {
        // Check for cancellation between sequential tasks
        guard !Task.isCancelled else {
          throw StoreError.cancelled
        }

        lastResult = try await self.executeTask(task)
      }

      return lastResult
    }
  }
}
