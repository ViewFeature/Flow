import Foundation

/// Errors that occur within the Flow framework's core store operations.
///
/// `StoreError` represents framework-level errors related to store lifecycle
/// and API misuse. These are distinct from application-domain errors, which
/// should be defined by the application itself.
///
/// ## Error Categories
///
/// ### Lifecycle Errors
/// - ``deallocated``: Store was deallocated during an async operation
/// - ``cancelled``: Operation was explicitly cancelled
///
/// ### API Misuse Errors
/// - ``noTasksToExecute(context:)``: Attempted to concatenate empty task array
///
/// ## Example: Handling Store Errors
/// ```swift
/// do {
///     let task = try ActionTask.concatenate(tasks)
///     return task
/// } catch let error as StoreError {
///     // Handle framework-level errors
///     print("Store error: \(error)")
///     return .none
/// } catch {
///     // Handle application-specific errors
///     return .none
/// }
/// ```
///
/// ## Topics
/// ### Error Cases
/// - ``deallocated``
/// - ``cancelled``
/// - ``noTasksToExecute(context:)``
public enum StoreError: Error, Sendable {
  /// The store was deallocated before the operation could complete.
  ///
  /// This occurs when the `Store` instance is released while an async task
  /// is still running. This is typically not an error condition in SwiftUI apps
  /// where view dismissal naturally cancels ongoing operations.
  case deallocated

  /// The operation was cancelled.
  ///
  /// This occurs when a task is explicitly cancelled via its cancellation ID
  /// or when the parent operation is cancelled.
  case cancelled

  /// No tasks provided to concatenate.
  ///
  /// Thrown when attempting to concatenate an empty task array.
  /// This typically indicates a logic error where tasks were expected but none were generated.
  ///
  /// ## Why This Is An Error
  ///
  /// Empty task arrays usually indicate a programming mistake:
  /// - Forgot to check if data is available
  /// - Applied filters that removed all items
  /// - Logic error in task generation
  ///
  /// Making this an error helps catch bugs early during development.
  ///
  /// ## Recovery
  ///
  /// If empty task lists are valid for your use case, explicitly check before concatenating:
  /// ```swift
  /// guard !tasks.isEmpty else {
  ///   return .none  // Explicitly handle empty case
  /// }
  /// return try .concatenate(tasks)
  /// ```
  ///
  /// ## Debugging
  ///
  /// Check why the task array is empty:
  /// - Is the data source empty?
  /// - Is there a filter that's too restrictive?
  /// - Is there a mapping error?
  ///
  /// - Parameter context: Additional context about where the error occurred
  case noTasksToExecute(context: String? = nil)
}

// MARK: - LocalizedError Conformance

extension StoreError: LocalizedError {
  /// User-facing error description.
  public var errorDescription: String? {
    switch self {
    case .deallocated:
      return "The store was deallocated before the operation could complete."

    case .cancelled:
      return "The operation was cancelled."

    case .noTasksToExecute(let context):
      if let context = context {
        return """
          No tasks to execute in \(context). Empty task arrays are not allowed. \
          If this is intentional, explicitly return .none instead.
          """
      }
      return """
        No tasks to execute. Empty task arrays are not allowed. \
        If empty is valid, explicitly check and return .none.
        """
    }
  }

  /// Recovery suggestion for the user.
  public var recoverySuggestion: String? {
    switch self {
    case .deallocated:
      return "Ensure the store remains in memory for the duration of the operation."

    case .cancelled:
      return "This is expected behavior when operations are cancelled."

    case .noTasksToExecute:
      return """
        Check if empty is expected:

        guard !tasks.isEmpty else {
          return .none  // Explicit: empty is OK
        }
        return try .concatenate(tasks)
        """
    }
  }

  /// Additional failure reason (for debugging).
  public var failureReason: String? {
    switch self {
    case .deallocated:
      return "Store instance was released during an async operation"

    case .cancelled:
      return "Task was cancelled before completion"

    case .noTasksToExecute(let context):
      if let context = context {
        return "Empty task array in \(context)"
      }
      return "Empty task array provided to concatenate"
    }
  }
}

// MARK: - CustomStringConvertible

extension StoreError: CustomStringConvertible {
  /// Human-readable description for debugging.
  public var description: String {
    errorDescription ?? "Unknown Store error"
  }
}

// MARK: - CustomDebugStringConvertible

extension StoreError: CustomDebugStringConvertible {
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

    return "StoreError(\n  \(components.joined(separator: "\n  "))\n)"
  }
}
