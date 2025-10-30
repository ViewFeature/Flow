import Foundation

/// A protocol that defines the core behavior of a feature in the Flow architecture.
///
/// `Feature` is the fundamental building block for creating modular, testable features.
/// Each feature encapsulates its own state, actions, and business logic, following the
/// single responsibility principle.
///
/// ## MainActor Execution
/// All action processing and state mutations occur on the **MainActor**, ensuring thread-safe
/// UI updates and seamless SwiftUI integration. You don't need to manually add `@MainActor`
/// annotations - the framework handles this automatically.
///
/// ## Overview
/// Features provide a clean separation of concerns by:
/// - Defining their own state and action types
/// - Implementing domain-specific logic in a testable manner (all on MainActor)
/// - Supporting asynchronous operations through task management
/// - Enabling composition with middleware and error handling
///
/// ## Implementation Pattern
/// ```swift
/// struct UserFeature: Feature {
///   // 1. Define your state (nested)
///   @Observable
///   final class State {
///     var user: User?
///     var isLoading = false
///     var isAuthenticated = false
///
///     init(user: User? = nil, isLoading: Bool = false, isAuthenticated: Bool = false) {
///       self.user = user
///       self.isLoading = isLoading
///       self.isAuthenticated = isAuthenticated
///     }
///   }
///
///   // 2. Define your actions (nested)
///   enum Action: Sendable {
///     case login(credentials: Credentials)
///     case logout
///     case setLoading(Bool)
///   }
///
///   // 3. Create your action handler
///   func handle() -> ActionHandler<Action, State, Void> {
///     ActionHandler { action, state in
///       switch action {
///       case .login(let credentials):
///         state.isLoading = true          // ← Direct state mutation
///         return .run { state in          // ← Same state instance (reference type)
///           let user = try await authService.login(credentials)
///           state.user = user             // ← Mutations visible to outer scope
///           state.isAuthenticated = true
///           state.isLoading = false
///         }
///
///       case .logout:
///         state.user = nil                // ← Multiple mutations
///         state.isAuthenticated = false   // ← in single action
///         return .none                    // ← No side effects
///
///       case .setLoading(let loading):
///         state.isLoading = loading
///         return .none
///       }
///     }
///   }
/// }
/// ```
///
/// - Note: In the `.run` closure, the `state` parameter refers to the same instance as the outer
///   `state` parameter (State is a reference type). All mutations inside `.run` are immediately
///   visible to the outer scope. This allows you to update state both before and during async
///   operations while maintaining a single source of truth.
///
/// ## Task Management
/// Your action handlers can return different task types:
///
/// - **`ActionTask.none`**: For synchronous state-only changes (no result value)
/// - **`ActionTask.just(_:)`**: For synchronous state changes that return a result value
/// - **`ActionTask.run(operation:)`**: For asynchronous operations (network, database, etc.)
/// - **`ActionTask.cancel(id:)`**: For cancelling running tasks by ID
///
/// ## Best Practices
/// - Keep features focused on a single domain (user management, settings, etc.)
/// - Use @Observable class for state to enable SwiftUI observation
/// - Define State and Action as nested types within the feature
/// - Make actions descriptive and domain-specific
/// - Handle errors gracefully using `.run` with error handling
///
/// ## Topics
/// ### Associated Types
/// - ``Action``
/// - ``State``
///
/// ### Creating Handlers
/// - ``handle()``
///
/// ### Related Documentation
/// - ``Store``
/// - ``ActionHandler``
/// - ``ActionTask``
public protocol Feature: Sendable {
  /// The type representing actions that can be sent to this feature.
  ///
  /// Actions describe events or user intentions that trigger state changes.
  /// They must conform to `Sendable` for safe concurrency.
  /// Define as a nested enum within your feature for better namespacing.
  ///
  /// ## Example
  /// ```swift
  /// struct CounterFeature: Feature {
  ///   enum Action: Sendable {
  ///     case increment
  ///     case decrement
  ///     case reset
  ///   }
  /// }
  /// ```
  associatedtype Action: Sendable

  /// The type representing the state managed by this feature.
  ///
  /// State should be an @Observable class for SwiftUI integration.
  /// Equatable conformance is optional but recommended for better testability.
  /// Define as a nested class within your feature for better namespacing.
  ///
  /// ## Example
  /// ```swift
  /// struct CounterFeature: Feature {
  ///   @Observable
  ///   final class State {
  ///     var count = 0
  ///     var lastUpdated: Date?
  ///
  ///     init(count: Int = 0, lastUpdated: Date? = nil) {
  ///       self.count = count
  ///       self.lastUpdated = lastUpdated
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// - Note: @Observable requires class types for SwiftUI observation
  /// - Warning: Your State class **must** use the `@Observable` macro for SwiftUI integration.
  ///   The type system cannot enforce this requirement. Forgetting `@Observable` will cause
  ///   SwiftUI views to not update automatically when state changes, and the compiler will
  ///   not warn you. Always verify your State class has the `@Observable` annotation.
  associatedtype State: AnyObject

  /// The type representing the result returned from action processing.
  ///
  /// ActionResult allows you to define what result type your actions return,
  /// enabling you to distinguish between different success patterns without
  /// storing temporary results in State.
  ///
  /// ActionResult is **inferred automatically** from your `handle()` method's return type.
  /// You don't need to explicitly declare it with `typealias`.
  ///
  /// ## Example: Custom Result Type
  /// ```swift
  /// struct SaveFeature: Feature {
  ///   enum SaveResult: Sendable {
  ///     case created(id: String)
  ///     case updated
  ///     case noChange
  ///   }
  ///
  ///   // ActionResult is inferred as SaveResult from handle() return type
  ///   func handle() -> ActionHandler<Action, State, SaveResult> {
  ///     ActionHandler { action, state in
  ///       switch action {
  ///       case .save(let data):
  ///         // Synchronous - return result immediately
  ///         if let existing = state.items.first(where: { $0.id == data.id }) {
  ///           state.items[existing] = data
  ///           return .just(.updated)
  ///         } else {
  ///           let id = UUID().uuidString
  ///           state.items.append(data.with(id: id))
  ///           return .just(.created(id: id))
  ///         }
  ///       }
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// ## Example: Void Result (Most Common)
  /// ```swift
  /// struct CounterFeature: Feature {
  ///   // ActionResult is inferred as Void from handle() return type
  ///   func handle() -> ActionHandler<Action, State, Void> {
  ///     ActionHandler { action, state in
  ///       switch action {
  ///       case .increment:
  ///         state.count += 1
  ///         return .none  // No result to return
  ///       }
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// ## Usage in Views
  /// ```swift
  /// Button("Save") {
  ///   Task {
  ///     let result = await store.send(.save).value
  ///     switch result {
  ///     case .success(.created(let id)):
  ///       navigateToDetail(id)
  ///     case .success(.updated):
  ///       showToast("Updated")
  ///     case .failure(let error):
  ///       showError(error)
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// - Note: ActionResult represents the type definition for operation results.
  ///   Use State for data that needs to be persisted or displayed.
  ///   The type is automatically inferred from your `handle()` method signature.
  associatedtype ActionResult: Sendable

  /// Creates an ActionHandler that processes actions for this feature on the MainActor.
  ///
  /// The handler receives actions and a state parameter (reference type), allowing direct
  /// mutation for optimal performance. All state mutations occur on the **MainActor**,
  /// ensuring thread-safe UI updates. It returns a ``ActionTask`` to handle
  /// any asynchronous side effects.
  ///
  /// - Note: The `handle()` method is called **once** during Store initialization.
  ///   The returned ``ActionHandler`` instance is reused for all subsequent actions.
  ///   Do not call `handle()` multiple times or store it separately - let the Store
  ///   manage the ActionHandler lifecycle.
  ///
  /// ## Example
  /// ```swift
  /// func handle() -> ActionHandler<Action, State, ActionResult> {
  ///   ActionHandler { action, state in
  ///     switch action {
  ///     case .increment:
  ///       state.count += 1  // ✅ Safe MainActor mutation
  ///       return .none
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// - Returns: A ActionHandler configured for this feature's action handling (runs on MainActor)
  func handle() -> ActionHandler<Action, State, ActionResult>
}
