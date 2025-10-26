import Foundation
import Logging

/// High-performance structured logging middleware for action processing.
///
/// `LoggingMiddleware` is the canonical example of a full-featured middleware implementation.
/// It demonstrates the complete middleware lifecycle: before action, after action, and error handling.
/// The middleware uses Swift's structured Logging framework to provide production-ready logging
/// with minimal performance overhead.
///
/// ## Key Features
/// - Structured logging with emoji markers for easy visual scanning
/// - Configurable log levels (debug, info, error)
/// - High-precision duration tracking in milliseconds
/// - Zero-cost when log level is insufficient
/// - Integration with system logging infrastructure
///
/// ## Architecture Role
/// LoggingMiddleware serves two purposes:
/// 1. **Development Tool**: Provides visibility into action flow during development
/// 2. **Reference Implementation**: Shows how to implement all three middleware protocols
///
/// ## Usage
/// Add logging to your feature's action handler:
/// ```swift
/// let handler = ActionHandler { action, state in
///   // Action handling logic
/// }
/// .use(LoggingMiddleware(
///   category: "MyFeature",
///   logLevel: .info  // Only log info and above
/// ))
/// ```
///
/// ## Log Output Format
/// The middleware produces structured logs with clear visual markers:
/// ```
/// 🎬 Action Started
/// Action: UserAction.login(credentials)
///
/// ✅ Action Completed
/// Action: UserAction.login(credentials)
/// Duration: 234.56ms
///
/// ❌ Action Failed
/// Action: UserAction.login(credentials)
/// Error: Network connection lost
/// ```
///
/// ## Performance Considerations
/// - Log level checks happen before any string formatting
/// - Duration tracking uses high-precision ContinuousClock
/// - Structured logging minimizes allocation overhead
/// - Subsystem/category enable filtering in production
///
/// ## Production Usage
/// For production builds, configure appropriate log levels:
/// ```swift
/// #if DEBUG
/// let logLevel: Logger.Level = .debug
/// #else
/// let logLevel: Logger.Level = .error  // Only errors in production
/// #endif
///
/// handler.use(LoggingMiddleware(
///   category: "ProductionFeature",
///   logLevel: logLevel
/// ))
/// ```
///
/// ## Topics
/// ### Creating Middleware
/// - ``init(category:logLevel:)``
///
/// ### Middleware Protocol Conformance
/// - ``beforeAction(_:state:)``
/// - ``afterAction(_:state:result:)``
/// - ``onError(_:action:state:)``
///
/// ### Properties
/// - ``id``
public final class LoggingMiddleware: ActionMiddleware, @unchecked Sendable {
  // MARK: - Constants

  private static let millisecondsPerSecond: Double = 1000.0
  private static let durationFormatPrecision = "%.2f"

  // MARK: - Properties

  /// Unique identifier for this middleware instance.
  ///
  /// Used by ``MiddlewareManager`` for tracking and debugging.
  public let id = "Flow.Logging"

  private let logger: Logger
  private let logLevel: Logger.Level

  // Track action start times for duration calculation
  private var startTimes: [String: ContinuousClock.Instant] = [:]

  /// Creates a new logging middleware with specified configuration.
  ///
  /// The middleware automatically configures the subsystem from the app's bundle identifier
  /// and combines it with the category to create a hierarchical logging label.
  ///
  /// - Parameters:
  ///   - category: The logging category (default: "Flow")
  ///   - logLevel: Minimum log level to emit (default: .debug)
  ///
  /// ## Example
  /// ```swift
  /// // Basic usage with defaults
  /// let logging = LoggingMiddleware()
  ///
  /// // Custom category for feature-specific logs
  /// let userLogging = LoggingMiddleware(
  ///   category: "UserManagement",
  ///   logLevel: .info
  /// )
  ///
  /// // Production configuration
  /// let prodLogging = LoggingMiddleware(
  ///   category: "ProductionApp",
  ///   logLevel: .error  // Only log errors
  /// )
  /// ```
  ///
  /// - Note: The full logger label will be "bundleId.category" (e.g., "com.example.app.UserManagement")
  public init(category: String = "Flow", logLevel: Logger.Level = .debug) {
    let subsystem = Bundle.main.bundleIdentifier ?? "com.viewfeature.library"
    self.logger = Logger(label: "\(subsystem).\(category)")
    self.logLevel = logLevel
  }

  /// Called before an action is processed.
  ///
  /// Logs the action start event at debug level with an emoji marker for easy identification.
  /// Also records the start time for duration tracking.
  ///
  /// - Parameters:
  ///   - action: The action about to be processed
  ///   - state: The current state (read-only)
  ///
  /// ## Output Format
  /// ```
  /// 🎬 Action Started
  /// Action: CounterAction.increment
  /// ```
  public func beforeAction<Action, State>(
    _ action: Action,
    state _: State
  ) async {
    // Record start time for duration calculation
    let actionKey = String(describing: action)
    startTimes[actionKey] = ContinuousClock.now

    guard shouldLog(.debug) else { return }

    logger.debug(
      """
      🎬 Action Started
      Action: \(actionKey)
      """)
  }

  /// Called after an action is successfully processed.
  ///
  /// Logs the action completion event at info level, including the action and execution duration
  /// in milliseconds with high precision.
  ///
  /// - Parameters:
  ///   - action: The action that was processed
  ///   - state: The updated state (read-only)
  ///   - result: The task returned by the action handler
  ///
  /// ## Output Format
  /// ```
  /// ✅ Action Completed
  /// Action: UserAction.login(credentials)
  /// Duration: 234.56ms
  /// ```
  public func afterAction<Action, State, ActionResult>(
    _ action: Action,
    state _: State,
    result _: ActionTask<Action, State, ActionResult>
  ) async where ActionResult: Sendable {
    // Calculate duration from recorded start time
    let actionKey = String(describing: action)
    let duration: TimeInterval
    if let startTime = startTimes[actionKey] {
      let elapsed = startTime.duration(to: ContinuousClock.now)
      duration =
        TimeInterval(elapsed.components.seconds) + TimeInterval(elapsed.components.attoseconds)
        / 1e18
      startTimes.removeValue(forKey: actionKey)
    } else {
      duration = 0
    }

    guard shouldLog(.info) else { return }

    logger.info(
      """
      ✅ Action Completed
      Action: \(actionKey)
      Duration: \(String(format: Self.durationFormatPrecision, duration * Self.millisecondsPerSecond))ms
      """)
  }

  /// Called when an error occurs during action processing.
  ///
  /// Logs the error at error level with full context including the action that failed
  /// and the error's localized description.
  ///
  /// - Parameters:
  ///   - error: The error that occurred
  ///   - action: The action that caused the error
  ///   - state: The current state (read-only)
  ///
  /// ## Output Format
  /// ```
  /// ❌ Action Failed
  /// Action: DataAction.fetchUser(id: 123)
  /// Error: The Internet connection appears to be offline.
  /// ```
  ///
  /// - Note: This method never throws, following the Resilient Semantics of error handling middleware.
  public func onError<Action, State>(
    _ error: Error,
    action: Action,
    state _: State
  ) async {
    logger.error(
      """
      ❌ Action Failed
      Action: \(String(describing: action))
      Error: \(error.localizedDescription)
      """)
  }

  private func shouldLog(_ level: Logger.Level) -> Bool {
    level >= logLevel
  }
}
