import Foundation

/// Errors that can occur within the Flow framework.
///
/// `FlowError` provides user-friendly error messages with actionable suggestions
/// for common issues. All errors conform to `LocalizedError` for automatic localization
/// and helpful error descriptions.
///
/// ## Example Usage
/// ```swift
/// // In your Feature
/// ActionHandler { action, state in
///     switch action {
///     case .submit(let data):
///         guard validate(data) else {
///             state.error = FlowError.validationFailed(
///                 reason: "Email format is invalid",
///                 suggestion: "Please enter a valid email address"
///             )
///             return .none
///         }
///
///         return .run { state in
///             do {
///                 try await api.submit(data)
///             } catch {
///                 throw FlowError.networkError(underlying: error)
///             }
///         }
///     }
/// }
/// ```
///
/// ## Topics
/// ### Error Types
/// - ``validationFailed(reason:suggestion:)``
/// - ``networkError(underlying:)``
/// - ``taskError(taskId:underlying:)``
/// - ``middlewareError(middlewareId:underlying:)``
/// - ``stateError(reason:)``
public enum FlowError: Error {
  /// Validation failed during action processing.
  ///
  /// Use this when user input or state validation fails.
  ///
  /// - Parameters:
  ///   - reason: Why validation failed
  ///   - suggestion: How to fix the issue (optional)
  ///
  /// ## Example
  /// ```swift
  /// guard email.contains("@") else {
  ///     throw FlowError.validationFailed(
  ///         reason: "Email must contain @",
  ///         suggestion: "Enter a valid email like user@example.com"
  ///     )
  /// }
  /// ```
  case validationFailed(reason: String, suggestion: String? = nil)

  /// Network or API operation failed.
  ///
  /// Wraps underlying network errors with Flow context.
  ///
  /// - Parameter underlying: The original network error
  ///
  /// ## Example
  /// ```swift
  /// do {
  ///     try await api.fetch()
  /// } catch {
  ///     throw FlowError.networkError(underlying: error)
  /// }
  /// ```
  case networkError(underlying: Error)

  /// Task execution failed.
  ///
  /// Use this when a specific ActionTask fails.
  ///
  /// - Parameters:
  ///   - taskId: The ID of the failed task
  ///   - underlying: The original error
  ///
  /// ## Example
  /// ```swift
  /// return .run(id: "fetch-data") { state in
  ///     do {
  ///         try await fetchData()
  ///     } catch {
  ///         throw FlowError.taskError(
  ///             taskId: "fetch-data",
  ///             underlying: error
  ///         )
  ///     }
  /// }
  /// ```
  case taskError(taskId: String, underlying: Error)

  /// Middleware execution failed.
  ///
  /// Internal error indicating middleware encountered an issue.
  /// Note: Middleware should handle errors internally, but this provides
  /// a fallback for unexpected failures.
  ///
  /// - Parameters:
  ///   - middlewareId: The ID of the middleware that failed
  ///   - underlying: The original error
  case middlewareError(middlewareId: String, underlying: Error)

  /// Invalid state transition or state inconsistency.
  ///
  /// Use this when state becomes invalid or a transition is not allowed.
  ///
  /// - Parameter reason: Why the state is invalid
  ///
  /// ## Example
  /// ```swift
  /// case .checkout:
  ///     guard !state.cart.isEmpty else {
  ///         throw FlowError.stateError(
  ///             reason: "Cannot checkout with empty cart"
  ///         )
  ///     }
  /// ```
  case stateError(reason: String)

  /// Custom error with a specific message.
  ///
  /// Use this for domain-specific errors that don't fit other categories.
  ///
  /// - Parameters:
  ///   - message: The error message
  ///   - underlying: Optional underlying error
  case custom(message: String, underlying: Error? = nil)
}

// MARK: - LocalizedError Conformance

extension FlowError: LocalizedError {
  /// User-facing error description.
  public var errorDescription: String? {
    switch self {
    case .validationFailed(let reason, let suggestion):
      if let suggestion = suggestion {
        return "Validation failed: \(reason). \(suggestion)"
      }
      return "Validation failed: \(reason)"

    case .networkError(let underlying):
      return "Network error: \(underlying.localizedDescription)"

    case .taskError(let taskId, let underlying):
      return "Task '\(taskId)' failed: \(underlying.localizedDescription)"

    case .middlewareError(let middlewareId, let underlying):
      return "Middleware '\(middlewareId)' encountered an error: \(underlying.localizedDescription)"

    case .stateError(let reason):
      return "Invalid state: \(reason)"

    case .custom(let message, let underlying):
      if let underlying = underlying {
        return "\(message): \(underlying.localizedDescription)"
      }
      return message
    }
  }

  /// Recovery suggestion for the user.
  public var recoverySuggestion: String? {
    switch self {
    case .validationFailed(_, let suggestion):
      return suggestion

    case .networkError:
      return "Check your internet connection and try again."

    case .taskError(let taskId, _):
      return "Task '\(taskId)' can be retried or cancelled."

    case .middlewareError:
      return "This is an internal error. Please report this issue."

    case .stateError:
      return "Ensure the application is in a valid state before this operation."

    case .custom:
      return nil
    }
  }

  /// Additional failure reason (for debugging).
  public var failureReason: String? {
    switch self {
    case .validationFailed(let reason, _):
      return reason

    case .networkError(let underlying):
      return "Underlying network error: \(underlying)"

    case .taskError(let taskId, let underlying):
      return "Task '\(taskId)' failed with: \(underlying)"

    case .middlewareError(let middlewareId, let underlying):
      return "Middleware '\(middlewareId)' failed with: \(underlying)"

    case .stateError(let reason):
      return reason

    case .custom(_, let underlying):
      return underlying?.localizedDescription
    }
  }
}

// MARK: - CustomStringConvertible

extension FlowError: CustomStringConvertible {
  /// Human-readable description for debugging.
  public var description: String {
    errorDescription ?? "Unknown Flow error"
  }
}

// MARK: - CustomDebugStringConvertible

extension FlowError: CustomDebugStringConvertible {
  /// Detailed description for debugging.
  public var debugDescription: String {
    var components: [String] = []

    if let description = errorDescription {
      components.append("Description: \(description)")
    }

    if let reason = failureReason {
      components.append("Reason: \(reason)")
    }

    if let suggestion = recoverySuggestion {
      components.append("Suggestion: \(suggestion)")
    }

    return "FlowError(\n  \(components.joined(separator: "\n  "))\n)"
  }
}
