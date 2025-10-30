import Foundation

/// Action execution closure that mutates state and returns a task.
///
/// This typealias defines the signature for action processing logic used in ``ActionHandler``.
/// The closure receives an action and state, performs any necessary state mutations,
/// and returns an ``ActionTask`` for asynchronous side effects.
///
/// All execution occurs on the **MainActor**, ensuring thread-safe state mutations.
///
/// ## Example
/// ```swift
/// let execution: ActionExecution<MyAction, MyState, Void> = { action, state in
///   switch action {
///   case .increment:
///     state.count += 1
///     return .none
///   }
/// }
/// ```
///
/// ## Type Parameters
/// - `Action`: The action type to process (must be Sendable)
/// - `State`: The state type to mutate (must be AnyObject/reference type)
/// - `ActionResult`: The result type returned from action processing (must be Sendable)
///
/// ## See Also
/// - ``ActionHandler/init(_:)``
public typealias ActionExecution<Action, State, ActionResult> =
  @MainActor (Action, State) async -> ActionTask<Action, State, ActionResult>

/// A facade for action processing with fluent method chaining capabilities that can return typed results.
///
/// `ActionHandler` provides a clean, composable API for defining how your feature
/// processes actions and updates state on the **MainActor**, with the ability to return
/// typed result values. All action processing occurs on MainActor, ensuring thread-safe
/// state mutations and seamless SwiftUI integration.
///
/// It supports:
/// - Direct state mutation (all mutations occur on MainActor)
/// - Asynchronous task execution
/// - Returning typed result values
/// - Error handling
/// - Debug logging
/// - Task transformation
///
/// ## Basic Usage
/// ```swift
/// struct SaveFeature: Feature {
///   enum SaveResult: Sendable {
///     case created(id: String)
///     case updated
///   }
///
///   @Observable
///   final class State {
///     var items: [Item] = []
///   }
///
///   enum Action: Sendable {
///     case save(Item)
///     case update(Item)
///   }
///
///   func handle() -> ActionHandler<Action, State, SaveResult> {
///     ActionHandler { action, state in
///       switch action {
///       case .save(let item):
///         let id = UUID().uuidString
///         state.items.append(item.with(id: id))
///         return .just(.created(id: id))
///       case .update(let item):
///         if let index = state.items.firstIndex(where: { $0.id == item.id }) {
///           state.items[index] = item
///           return .just(.updated)
///         }
///         return .just(.updated)
///       }
///     }
///   }
/// }
/// ```
///
/// For simpler handlers that don't need to return results, use ``ActionHandler`` instead.
///
/// ## Method Chaining
/// Enhance your handler with additional functionality:
/// ```swift
/// struct MyFeature: Feature {
///   @Observable
///   final class State {
///     var errorMessage: String?
///   }
///
///   enum Action: Sendable {
///     case doSomething
///   }
///
///   func handle() -> ActionHandler<Action, State, Void> {
///     ActionHandler { action, state in
///       // action processing
///       return .none
///     }
///     .onError { error, state in
///       state.errorMessage = error.localizedDescription
///     }
///     .use(LoggingMiddleware(category: "MyFeature"))
///   }
/// }
/// ```
///
/// ## Topics
/// ### Creating Handlers
/// - ``init(_:)``
///
/// ### Processing Actions
/// - ``handle(action:state:)``
///
/// ### Method Chaining
/// - ``onError(_:)``
/// - ``use(_:)``
/// - ``transform(_:)``
///
/// ## Design Decision: Facade Pattern with Internal ActionProcessor
///
/// `ActionHandler` serves as a **public facade** over the internal `ActionProcessor` implementation.
/// This is an intentional architectural choice, not a limitation to address:
///
/// 1. **Separation of Concerns**:
///    - `ActionHandler` provides the public API for users (fluent method chaining)
///    - `ActionProcessor` handles internal orchestration (middleware, error handling, transforms)
///
/// 2. **Encapsulation**: Users interact only with `ActionHandler`. They don't need to know about
///    `ActionProcessor`, `MiddlewareManager`, or internal state management complexity.
///
/// 3. **Immutable Method Chaining**: The Facade pattern enables clean immutable chaining:
///    ```swift
///    ActionHandler { ... }
///      .use(middleware)
///      .onError { ... }
///    ```
///    Each method returns a new `ActionHandler` wrapping a modified `ActionProcessor`.
///
/// 4. **Why Not Protocol-ize ActionProcessor?**
///    - There's only one implementation (YAGNI principle)
///    - Protocol with associated types would complicate the simple facade pattern
///    - Current design already supports full testability via the public ActionHandler API
///
/// The Facade pattern here is a feature, not a code smell. It provides clean abstraction
/// and hides implementation complexity from users while maintaining full testability.
///
/// ## Type Constraints
///
/// Type parameters are constrained to match Feature protocol requirements:
/// - `Action: Sendable` ensures safe concurrent action dispatching
/// - `State: AnyObject` ensures reference semantics for direct state mutation
/// - `ActionResult: Sendable` ensures safe concurrent result handling
///
/// These constraints prevent common errors like using value-type State (which wouldn't
/// support mutation) or non-Sendable actions (which could cause data races).
public final class ActionHandler<Action: Sendable, State: AnyObject, ActionResult: Sendable> {
  private let processor: ActionProcessor<Action, State, ActionResult>

  /// Creates a ActionHandler with the given action processing logic.
  ///
  /// - Parameter actionLogic: A closure that processes actions and mutates state.
  ///   The closure receives an action and a state parameter (reference type), and returns
  ///   an ``ActionTask`` for any asynchronous side effects.
  ///
  /// ## Example
  /// ```swift
  /// struct SaveFeature: Feature {
  ///   enum SaveResult: Sendable {
  ///     case created(id: String)
  ///     case updated
  ///   }
  ///
  ///   @Observable
  ///   final class State {
  ///     var items: [Item] = []
  ///   }
  ///
  ///   enum Action: Sendable {
  ///     case save(Item)
  ///   }
  ///
  ///   func handle() -> ActionHandler<Action, State, SaveResult> {
  ///     ActionHandler { action, state in
  ///       switch action {
  ///       case .save(let item):
  ///         let id = UUID().uuidString
  ///         state.items.append(item.with(id: id))
  ///         return .just(.created(id: id))  // ✅ Correct: Return result
  ///       }
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// - Note: State is constrained to `AnyObject` (reference type). Mutate properties
  ///   directly (`state.count += 1`). Since State is passed as a reference, all mutations
  ///   are automatically reflected in the Store's state.
  public init(_ actionLogic: @escaping ActionExecution<Action, State, ActionResult>) {
    self.processor = ActionProcessor(actionLogic)
  }

  private init(processor: ActionProcessor<Action, State, ActionResult>) {
    self.processor = processor
  }

  /// Processes an action and updates the state.
  ///
  /// - Parameters:
  ///   - action: The action to process
  ///   - state: The current state (will be mutated)
  /// - Returns: An ``ActionTask`` containing any asynchronous side effects
  public func handle(action: Action, state: State) async -> ActionTask<Action, State, ActionResult> {
    await processor.process(action: action, state: state)
  }
}

// MARK: - Method Chaining Extensions

extension ActionHandler {
  /// Adds error handling to the action processing pipeline.
  ///
  /// - Parameter errorHandler: A closure that handles errors
  /// - Returns: A new ActionHandler with error handling
  public func onError(_ errorHandler: @escaping (Error, State) -> Void) -> ActionHandler<
    Action, State, ActionResult
  > {
    ActionHandler(processor: processor.onError(errorHandler))
  }

  /// Transforms the task returned by action processing.
  ///
  /// - Parameter taskTransform: A closure that transforms the task
  /// - Returns: A new ActionHandler with task transformation
  public func transform(
    _ taskTransform: @escaping (ActionTask<Action, State, ActionResult>)
      -> ActionTask<Action, State, ActionResult>
  ) -> ActionHandler<Action, State, ActionResult> {
    ActionHandler(processor: processor.transform(taskTransform))
  }

  /// Adds custom middleware to the action processing pipeline.
  ///
  /// - Parameter middleware: The middleware to add
  /// - Returns: A new ActionHandler with the middleware added
  public func use(_ middleware: some BaseActionMiddleware) -> ActionHandler<
    Action, State, ActionResult
  > {
    ActionHandler(processor: processor.use(middleware))
  }
}
