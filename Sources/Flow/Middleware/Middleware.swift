import Foundation

/// Base protocol for all action middleware.
///
/// `BaseActionMiddleware` defines the fundamental requirement for all middleware:
/// a unique identifier for tracking and debugging. This follows the Interface
/// Segregation Principle (ISP) by providing a minimal base interface.
///
/// ## Topics
/// ### Identifying Middleware
/// - ``id``
public protocol BaseActionMiddleware: Sendable {
  /// Unique identifier for this middleware instance.
  ///
  /// Used for logging, debugging, and middleware ordering. Should be a descriptive
  /// string that uniquely identifies this middleware type.
  ///
  /// ## Example
  /// ```swift
  /// public struct MyMiddleware: ActionMiddleware {
  ///   public let id = "com.myapp.MyMiddleware"
  /// }
  /// ```
  var id: String { get }
}

/// Middleware that executes before an action is processed.
///
/// Implement this protocol to add custom logic that runs before the action handler
/// processes an action. Common use cases include:
/// - Action logging
/// - State inspection
/// - Performance monitoring
/// - Analytics tracking
///
/// ## Example Implementation
/// ```swift
/// struct LoggingMiddleware: BeforeActionMiddleware {
///   let id = "LoggingMiddleware"
///
///   func beforeAction<Action, State>(_ action: Action, state: State) async {
///     print("Action: \(action)")
///   }
/// }
/// ```
///
/// ## Topics
/// ### Processing Actions
/// - ``beforeAction(_:state:)``
public protocol BeforeActionMiddleware: BaseActionMiddleware {
  /// Called before an action is processed.
  ///
  /// This method is for observation and logging only. It cannot prevent action processing.
  /// If you need to conditionally prevent actions, implement that logic in your Feature's `handle()` method.
  ///
  /// - Parameters:
  ///   - action: The action about to be processed
  ///   - state: The current state (read-only)
  func beforeAction<Action, State>(_ action: Action, state: State) async
}

/// Middleware that executes after an action is processed.
///
/// Implement this protocol to add custom logic that runs after the action handler
/// completes processing. Common use cases include:
/// - Analytics tracking
/// - Performance monitoring
/// - State change logging
/// - Metrics collection
///
/// ## Example Implementation
/// ```swift
/// struct AnalyticsMiddleware: AfterActionMiddleware {
///   let id = "AnalyticsMiddleware"
///
///   func afterAction<Action, State>(
///     _ action: Action,
///     state: State,
///     result: ActionTask<Action, State, Void>
///   ) async {
///     // Track action completion
///     analytics.track("action_completed", properties: [
///       "type": String(describing: action)
///     ])
///   }
/// }
/// ```
///
/// ## Topics
/// ### Processing Actions
/// - ``afterAction(_:state:result:)``
public protocol AfterActionMiddleware: BaseActionMiddleware {
  /// Called after an action is processed.
  ///
  /// This method is for observation and logging only. It cannot affect the action processing result.
  ///
  /// - Parameters:
  ///   - action: The action that was processed
  ///   - state: The updated state (read-only)
  ///   - result: The task returned by the action handler
  func afterAction<Action, State, ActionResult>(
    _ action: Action, state: State, result: ActionTask<Action, State, ActionResult>)
    async where ActionResult: Sendable
}

/// Middleware that handles errors during action processing.
///
/// Implement this protocol to add custom error handling logic. Common use cases include:
/// - Error logging
/// - Error recovery strategies
/// - User notification
/// - Error analytics
///
/// ## Error Handling Semantics
///
/// Error handlers follow **Resilient Semantics**:
/// - This method **never throws** and cannot fail the error handling pipeline
/// - If your implementation needs to call throwing functions, use `do-catch` or `try?` internally
/// - All error handlers are guaranteed to execute, even if some encounter issues
///
/// This design ensures best-effort error reporting that doesn't compound failures.
///
/// ## Example Implementation
/// ```swift
/// struct ErrorLoggingMiddleware: ErrorHandlingMiddleware {
///   let id = "ErrorLoggingMiddleware"
///
///   func onError<Action, State>(
///     _ error: Error,
///     action: Action,
///     state: State
///   ) async {
///     // Log error with context
///     logger.error("Action failed: \(error)", metadata: [
///       "action": String(describing: action),
///       "state": String(describing: state)
///     ])
///
///     // If you need to call throwing functions, handle errors explicitly
///     do {
///       try await sendToAnalytics(error)
///     } catch {
///       logger.warning("Analytics failed: \(error)")
///     }
///   }
/// }
/// ```
///
/// ## Topics
/// ### Handling Errors
/// - ``onError(_:action:state:)``
public protocol ErrorHandlingMiddleware: BaseActionMiddleware {
  /// Called when an error occurs during action processing.
  ///
  /// This method executes with **Resilient Semantics** and never throws. The error handling
  /// pipeline always continues to completion, ensuring all error handlers get a chance to execute.
  ///
  /// - Parameters:
  ///   - error: The error that occurred
  ///   - action: The action that caused the error
  ///   - state: The current state (read-only)
  ///
  /// - Note: This method does not throw. If you need to call throwing functions internally,
  ///   use `do-catch` blocks or `try?` to handle errors explicitly.
  func onError<Action, State>(_ error: Error, action: Action, state: State) async
}

/// Full-featured middleware that supports all processing stages.
///
/// `ActionMiddleware` combines all middleware protocols into a single interface.
/// Conform to this protocol when you need to implement middleware that handles
/// before, after, and error stages. For specialized middleware, conform to
/// individual protocols instead.
///
/// ## Example Implementation
/// ```swift
/// struct ComprehensiveMiddleware: ActionMiddleware {
///   let id = "ComprehensiveMiddleware"
///
///   func beforeAction<Action, State>(_ action: Action, state: State) async {
///     print("Before: \(action)")
///   }
///
///   func afterAction<Action, State>(
///     _ action: Action,
///     state: State,
///     result: ActionTask<Action, State, Void>
///   ) async {
///     print("After: \(action)")
///   }
///
///   func onError<Action, State>(_ error: Error, action: Action, state: State) async {
///     print("Error: \(error)")
///   }
/// }
/// ```
///
/// ## Topics
/// ### Middleware Protocol Composition
/// - ``BeforeActionMiddleware``
/// - ``AfterActionMiddleware``
/// - ``ErrorHandlingMiddleware``
public protocol ActionMiddleware: BeforeActionMiddleware, AfterActionMiddleware,
  ErrorHandlingMiddleware
{
}
