import Foundation

/// Manages and executes middleware in an action processing pipeline.
///
/// Executes middleware at three stages: before actions, after actions (with duration), and during error handling.
/// Middleware executes in registration order.
///
/// ## Execution Semantics
///
/// All middleware methods execute sequentially in registration order:
/// - `beforeAction`: Executes before the action handler
/// - `afterAction`: Executes after the action handler completes
/// - `onError`: Executes if an error occurs during action processing
///
/// ### Resilient Execution
/// - Middleware methods are for observation and logging only
/// - They cannot prevent action processing or throw errors
/// - All registered middleware will execute to completion
/// - Use case: Logging, analytics, performance monitoring
///
/// ## Example
/// ```swift
/// // Before-action middleware for logging
/// struct LoggingMiddleware: BeforeActionMiddleware {
///   func beforeAction(_ action: Action, state: State) async {
///     logger.info("Action: \(action)")
///   }
/// }
///
/// // Error-handling middleware for analytics
/// struct ErrorLoggingMiddleware: ErrorHandlingMiddleware {
///   func onError(_ error: Error, action: Action, state: State) async {
///     // Handle errors explicitly when calling throwing functions
///     do {
///       try await sendToAnalytics(error)
///     } catch {
///       logger.warning("Analytics failed: \(error)")
///     }
///   }
/// }
/// ```
@MainActor
public final class MiddlewareManager<Action, State> {
  private var middlewares: [any BaseActionMiddleware] = []

  // Cached middleware lists for performance (computed at initialization and when middleware is added)
  private var beforeMiddlewares: [any BeforeActionMiddleware] = []
  private var afterMiddlewares: [any AfterActionMiddleware] = []
  private var errorMiddlewares: [any ErrorHandlingMiddleware] = []

  /// Creates a new MiddlewareManager with optional initial middleware.
  public init(middlewares: [any BaseActionMiddleware] = []) {
    self.middlewares = middlewares

    // Cache filtered middleware lists for performance
    self.beforeMiddlewares = middlewares.compactMap { $0 as? any BeforeActionMiddleware }
    self.afterMiddlewares = middlewares.compactMap { $0 as? any AfterActionMiddleware }
    self.errorMiddlewares = middlewares.compactMap { $0 as? any ErrorHandlingMiddleware }
  }

  /// Returns all currently registered middleware.
  public var allMiddlewares: [any BaseActionMiddleware] {
    middlewares
  }

  /// Adds middleware to the execution pipeline (appended to end).
  public func addMiddleware(_ middleware: some BaseActionMiddleware) {
    middlewares.append(middleware)

    // Update cached middleware lists
    if let before = middleware as? any BeforeActionMiddleware {
      beforeMiddlewares.append(before)
    }
    if let after = middleware as? any AfterActionMiddleware {
      afterMiddlewares.append(after)
    }
    if let error = middleware as? any ErrorHandlingMiddleware {
      errorMiddlewares.append(error)
    }
  }

  /// Adds multiple middleware to the execution pipeline.
  ///
  /// Equivalent to calling ``addMiddleware(_:)`` for each middleware in the array.
  /// Order is preserved.
  ///
  /// - Parameter newMiddlewares: Array of middleware to add
  public func addMiddlewares(_ newMiddlewares: [any BaseActionMiddleware]) {
    for middleware in newMiddlewares {
      addMiddleware(middleware)
    }
  }

  /// Executes all before-action middleware in registration order.
  ///
  /// All middleware execute to completion. Middleware are for observation only
  /// and cannot prevent action processing.
  public func executeBeforeAction(action: Action, state: State) async {
    for middleware in beforeMiddlewares {
      await middleware.beforeAction(action, state: state)
    }
  }

  /// Executes all after-action middleware in registration order.
  ///
  /// All middleware execute to completion. Middleware are for observation only
  /// and cannot affect the action processing result.
  public func executeAfterAction<ActionResult>(
    action: Action, state: State, result: ActionTask<Action, State, ActionResult>
  ) async where ActionResult: Sendable {
    for middleware in afterMiddlewares {
      await middleware.afterAction(action, state: state, result: result)
    }
  }

  /// Executes all error-handling middleware in registration order.
  ///
  /// All error handlers are guaranteed to execute. Error handlers cannot throw
  /// and must handle errors internally using `do-catch` or `try?`.
  public func executeErrorHandling(error: Error, action: Action, state: State) async {
    for middleware in errorMiddlewares {
      await middleware.onError(error, action: action, state: state)
    }
  }
}
