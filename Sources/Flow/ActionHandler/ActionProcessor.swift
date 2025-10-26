import Foundation

/// Action execution closure that mutates state and returns a task.
public typealias ActionExecution<Action, State, ActionResult> =
  @MainActor (Action, State) async ->
  ActionTask<Action, State, ActionResult>

/// Error handler closure that can mutate state in response to errors.
public typealias StateErrorHandler<State> = (Error, State) -> Void

/// Core action processing engine with integrated middleware pipeline.
///
/// `ActionProcessor` orchestrates the complete action processing lifecycle on the **MainActor**:
/// middleware execution, timing, error handling, and task transformation. All action processing
/// occurs on MainActor, ensuring thread-safe state mutations and seamless SwiftUI integration.
///
/// Supports immutable method chaining via `use()`, `onError()`, and `transform()`.
///
/// ```swift
/// let processor = ActionProcessor { action, state in
///   switch action {
///   case .increment: state.count += 1; return .none
///   }
/// }
/// .use(LoggingMiddleware())
/// .onError { error, state in state.errorMessage = "\(error)" }
/// ```
public final class ActionProcessor<Action, State, ActionResult: Sendable> {
  private let baseExecution: ActionExecution<Action, State, ActionResult>
  private let errorHandler: StateErrorHandler<State>?
  private let middlewareManager: MiddlewareManager<Action, State>

  /// Creates an ActionProcessor with the given action execution logic.
  public init(_ execution: @escaping ActionExecution<Action, State, ActionResult>) {
    self.baseExecution = execution
    self.errorHandler = nil
    self.middlewareManager = MiddlewareManager()
  }

  internal init(
    execution: @escaping ActionExecution<Action, State, ActionResult>,
    errorHandler: StateErrorHandler<State>?,
    middlewareManager: MiddlewareManager<Action, State>
  ) {
    self.baseExecution = execution
    self.errorHandler = errorHandler
    self.middlewareManager = middlewareManager
  }

  /// Processes an action through the middleware pipeline.
  ///
  /// Executes before-action middleware, action logic, after-action middleware, and error handling if needed.
  public func process(action: Action, state: State) async -> ActionTask<Action, State, ActionResult> {
    await executeWithMiddleware(action: action, state: state)
  }

  private func executeWithMiddleware(
    action: Action,
    state: State
  ) async -> ActionTask<Action, State, ActionResult> {
    await middlewareManager.executeBeforeAction(action: action, state: state)
    let result = await baseExecution(action, state)
    await middlewareManager.executeAfterAction(
      action: action, state: state, result: result)
    return result
  }

  /// Adds middleware to the processing pipeline (executed in order added).
  public func use(_ middleware: some BaseActionMiddleware) -> ActionProcessor<
    Action, State, ActionResult
  > {
    let newMiddlewareManager = MiddlewareManager<Action, State>(
      middlewares: middlewareManager.allMiddlewares + [middleware]
    )

    return ActionProcessor(
      execution: baseExecution,
      errorHandler: errorHandler,
      middlewareManager: newMiddlewareManager
    )
  }

  /// Adds error handling to the processing pipeline. Called after error middleware executes.
  ///
  /// ```swift
  /// processor.onError { error, state in
  ///   state.errorMessage = error.localizedDescription
  ///   state.isLoading = false
  /// }
  /// ```
  public func onError(_ handler: @escaping (Error, State) -> Void) -> ActionProcessor<
    Action, State, ActionResult
  > {
    ActionProcessor(
      execution: baseExecution,
      errorHandler: handler,
      middlewareManager: middlewareManager
    )
  }

  /// Transforms the task returned by action processing.
  ///
  /// Useful for adding cross-cutting concerns like logging, timeouts, or error handling to all tasks.
  ///
  /// ```swift
  /// processor.transform { task in
  ///   switch task.storeTask {
  ///   case .run(let id, let operation, _):
  ///     return .run(id: id) { state in
  ///       print("Task \(id ?? "unknown") starting")
  ///       try await operation(state)
  ///     }
  ///   default: return task
  ///   }
  /// }
  /// ```
  public func transform(
    _ transform: @escaping (ActionTask<Action, State, ActionResult>) -> ActionTask<
      Action, State, ActionResult
    >
  ) -> ActionProcessor<Action, State, ActionResult> {
    let transformedExecution:
      @MainActor (Action, State) async -> ActionTask<Action, State, ActionResult> =
        { action, state in
          let result = await self.baseExecution(action, state)
          return transform(result)
        }

    return ActionProcessor(
      execution: transformedExecution,
      errorHandler: errorHandler,
      middlewareManager: middlewareManager
    )
  }
}
