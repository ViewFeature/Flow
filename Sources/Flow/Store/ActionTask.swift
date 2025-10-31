import Foundation
import Synchronization

// MARK: - TaskID Protocol

/// Protocol for types that can be converted to task ID strings.
public protocol TaskIDConvertible: Hashable, Sendable {
  /// Converts the task ID to a string representation.
  var taskIdString: String { get }
}

/// Default implementations for common types
extension String: TaskIDConvertible {
  public var taskIdString: String { self }
}

extension Int: TaskIDConvertible {
  public var taskIdString: String { String(self) }
}

extension UUID: TaskIDConvertible {
  public var taskIdString: String { uuidString }
}

/// Default implementation for CustomStringConvertible types
extension TaskIDConvertible where Self: CustomStringConvertible {
  public var taskIdString: String { description }
}

/// Default implementation for RawRepresentable types (enums with String raw value)
extension TaskIDConvertible where Self: RawRepresentable, RawValue == String {
  public var taskIdString: String { rawValue }
}

/// Task identifiers (String, Int, UUID, or custom enums).
public typealias TaskID = TaskIDConvertible

// MARK: - TaskID Generator

/// Generates unique task IDs using atomic counter (faster than UUID)
private enum TaskIdGenerator {
  private static let counter = Atomic<UInt64>(0)

  static func generate() -> String {
    let id = counter.wrappingAdd(1, ordering: .relaxed)
    return "auto-task-\(id)"
  }
}

// MARK: - ActionTask

/// Represents asynchronous work returned from action processing.
///
/// `ActionTask` provides a composable, type-safe way to express asynchronous side effects
/// in your application. All task operations execute on the **MainActor**, ensuring thread-safe
/// state access and seamless SwiftUI integration.
///
/// ## Core Operations
///
/// **Creating Tasks:**
/// ```swift
/// // Simple asynchronous task
/// return .run { state in
///   let data = try await api.fetch()
///   state.data = data  // ✅ Safe MainActor mutation
/// }
///
/// // Cancellable task
/// return .run { state in
///   let data = try await api.fetch()
///   state.data = data
/// }
/// .cancellable(id: "fetch", cancelInFlight: true)
///
/// // With error handling
/// return .run { state in
///   let data = try await api.fetch()
///   state.data = data
/// }
/// .catch { error, state in
///   state.errorMessage = "\(error)"
/// }
/// ```
///
/// **Cancelling Tasks:**
/// ```swift
/// // Cancel a single task
/// return .cancel(id: "fetch")
///
/// // Cancel multiple tasks
/// return .cancel(ids: ["fetch-1", "fetch-2"])
/// ```
///
/// ## Returning Results
///
/// Actions can return typed results using the `ActionResult` associatedtype:
///
/// ```swift
/// struct MyFeature: Feature {
///     enum SaveResult: Sendable {
///         case created(id: UUID)
///         case updated
///         case noChange
///     }
///
///     // ActionResult is inferred as SaveResult from handle() return type
///     func handle() -> ActionHandler<Action, State, SaveResult> {
///         ActionHandler { action, state in
///             switch action {
///             case .save(let data):
///                 if let existing = state.items.first(where: { $0.id == data.id }) {
///                     state.items[existing] = data
///                     return .just(.updated)
///                 } else {
///                     let id = UUID()
///                     state.items.append(data.with(id: id))
///                     return .just(.created(id: id))
///                 }
///             }
///         }
///     }
/// }
///
/// // Caller can await and check the result
/// let result = await store.send(.save(data)).value
/// switch result {
/// case .success(.created(let id)):
///     print("Created with ID: \(id)")
/// case .success(.updated):
///     print("Updated existing item")
/// case .failure(let error):
///     print("Error: \(error)")
/// }
/// ```
///
/// ## Parallel Execution
///
/// For parallel task execution, use Swift's native `async let`:
///
/// ```swift
/// return .run { state in
///     async let users = api.fetchUsers()
///     async let posts = api.fetchPosts()
///     async let comments = api.fetchComments()
///
///     state.users = try await users
///     state.posts = try await posts
///     state.comments = try await comments
/// }
/// ```
///
/// ## Sequential Execution
///
/// Use `.concatenate` for step-by-step workflows:
///
/// ```swift
/// return .concatenate(
///     .run { state in
///         state.step = 1
///         try await Task.sleep(for: .seconds(1))
///     },
///     .run { state in
///         state.step = 2
///         try await Task.sleep(for: .seconds(1))
///     },
///     .run { state in
///         state.step = 3
///     }
/// )
/// ```
///
/// ## Topics
/// ### Creating Tasks
/// - ``none``
/// - ``just(_:)``
/// - ``run(operation:)``
/// - ``cancel(id:)``
/// - ``cancel(ids:)``
///
/// ### Configuring Tasks
/// - ``catch(_:)``
/// - ``cancellable(id:cancelInFlight:)``
/// - ``priority(_:)``
///
/// - Note: The `Action` type parameter is required for type system consistency
///   with `ActionHandler<Action, State>` and middleware protocols, even though
///   it's not directly used in the internal `Operation` enum.
///   The `ActionResult` type parameter represents the value returned from action processing.
// periphery:ignore - Action type parameter is intentionally unused but required for type consistency
public struct ActionTask<Action, State, ActionResult: Sendable> {
  // MARK: - Internal Operation Type

  /// Internal representation of task operations.
  ///
  /// Uses `indirect` cases for composition to support recursive task structures.
  internal enum Operation {
    /// Returns a result immediately without performing any asynchronous work
    case just(result: ActionResult)

    /// Execute an asynchronous operation that returns a result
    case run(
      id: String,
      name: String?,
      operation: @MainActor (State) async throws -> ActionResult,
      onError: (@MainActor (Error, State) -> Void)?,
      cancelInFlight: Bool,
      priority: TaskPriority?
    )

    /// Cancel running tasks by their IDs and return a result
    case cancel(ids: [String], result: ActionResult)

    /// Concatenate two tasks to run sequentially
    indirect case concatenated(ActionTask, ActionTask)
  }

  internal let operation: Operation

  /// Internal initializer
  private init(operation: Operation) {
    self.operation = operation
  }
}

// MARK: - Factory Methods

extension ActionTask where ActionResult == Void {
  /// Returns a task that performs no asynchronous work with a Void result.
  ///
  /// ## Example
  /// ```swift
  /// case .increment:
  ///   state.count += 1
  ///   return .none
  /// ```
  public static var none: ActionTask {
    ActionTask(operation: .just(result: ()))
  }
}

extension ActionTask {
  /// Returns a task that immediately returns the given result value.
  ///
  /// Similar to Combine's `Just`, this wraps a value in a `ActionTask` that
  /// completes synchronously, without performing any asynchronous work.
  ///
  /// Use this when an action completes synchronously but needs to communicate
  /// its outcome to the caller.
  ///
  /// ## Example
  /// ```swift
  /// enum SaveResult: Sendable {
  ///     case created(id: UUID)
  ///     case updated
  ///     case noChange
  /// }
  ///
  /// case .save(let data):
  ///     if let existing = state.items.first(where: { $0.id == data.id }) {
  ///         state.items[existing] = data
  ///         return .just(.updated)
  ///     } else {
  ///         let id = UUID()
  ///         state.items.append(data.with(id: id))
  ///         return .just(.created(id: id))
  ///     }
  /// ```
  ///
  /// - Parameter result: The result value to return
  /// - Returns: A task that completes immediately with the given result
  public static func just(_ result: ActionResult) -> ActionTask {
    ActionTask(operation: .just(result: result))
  }

  /// Creates an asynchronous task that returns a result.
  ///
  /// The task executes on the MainActor, allowing safe state mutations.
  /// Use `.cancellable(id:cancelInFlight:)` to make the task cancellable by a specific ID.
  ///
  /// ## Example
  /// ```swift
  /// // Task that returns a result
  /// return .run { state in
  ///   let outcome = try await api.save(state.data)
  ///   state.data = outcome.data
  ///   return .created(id: outcome.id)
  /// }
  ///
  /// // Named task for better debugging
  /// return .run(name: "🔄 Fetch user data") { state in
  ///   let data = try await fetch()
  ///   state.data = data
  ///   return .fetched
  /// }
  /// .cancellable(id: "fetch", cancelInFlight: true)
  /// ```
  ///
  /// - Parameters:
  ///   - name: Optional human-readable name for the task (useful for debugging and profiling)
  ///   - operation: The async operation to execute, receiving mutable state and returning a result
  /// - Returns: A new `ActionTask` that will execute the operation
  public static func run(
    name: String? = nil,
    operation: @escaping @MainActor (State) async throws -> ActionResult
  ) -> ActionTask {
    let taskId = TaskIdGenerator.generate()
    return ActionTask(
      operation: .run(
        id: taskId,
        name: name,
        operation: operation,
        onError: nil,
        cancelInFlight: false,
        priority: nil
      ))
  }

  /// Cancels a running task by its ID.
  ///
  /// This variant is available only when `ActionResult == Void`.
  /// The task will be cancelled and `()` will be returned.
  ///
  /// For non-Void results, use `.cancel(id:returning:)`.
  ///
  /// If the task isn't running, this operation does nothing.
  ///
  /// ## Example
  /// ```swift
  /// case .cancelFetch:
  ///   return .cancel(id: "fetch")
  /// ```
  ///
  /// - Parameter id: The identifier of the task to cancel
  /// - Returns: A new `ActionTask` that will cancel the specified task and return `()`
  public static func cancel<ID: TaskID>(id: ID) -> ActionTask where ActionResult == Void {
    let stringId = id.taskIdString
    return ActionTask(operation: .cancel(ids: [stringId], result: ()))
  }

  /// Cancels multiple running tasks by their IDs.
  ///
  /// This variant is available only when `ActionResult == Void`.
  /// The tasks will be cancelled and `()` will be returned.
  ///
  /// For non-Void results, use `.cancel(ids:returning:)`.
  ///
  /// Tasks that aren't running are ignored. This is useful for cancelling
  /// a group of related tasks at once.
  ///
  /// ## Example
  /// ```swift
  /// // Cancel all download tasks
  /// return .cancel(ids: ["download-1", "download-2", "download-3"])
  ///
  /// // Cancel tasks from an array
  /// let taskIds = state.activeDownloads.map(\.id)
  /// return .cancel(ids: taskIds)
  /// ```
  ///
  /// - Parameter ids: An array of task identifiers to cancel
  /// - Returns: A new `ActionTask` that will cancel the specified tasks and return `()`
  public static func cancel<ID: TaskID>(ids: [ID]) -> ActionTask where ActionResult == Void {
    let stringIds = ids.map { $0.taskIdString }
    return ActionTask(operation: .cancel(ids: stringIds, result: ()))
  }

  /// Cancels a running task by its ID and returns a result.
  ///
  /// Unlike `.cancel(id:)` which requires `ActionResult == Void`,
  /// this variant allows you to return a meaningful result after cancellation.
  ///
  /// If the task isn't running, this operation does nothing but still returns the result.
  ///
  /// ## Example
  /// ```swift
  /// enum MyResult: Sendable {
  ///     case cancelled
  ///     case success(Data)
  /// }
  ///
  /// case .cancelFetch:
  ///     return .cancel(id: "fetch", returning: .cancelled)
  /// ```
  ///
  /// - Parameters:
  ///   - id: The identifier of the task to cancel
  ///   - result: The result value to return after cancellation
  /// - Returns: A new `ActionTask` that will cancel the specified task and return the result
  public static func cancel<ID: TaskID>(
    id: ID,
    returning result: ActionResult
  ) -> ActionTask {
    let stringId = id.taskIdString
    return ActionTask(operation: .cancel(ids: [stringId], result: result))
  }

  /// Cancels multiple running tasks by their IDs and returns a result.
  ///
  /// Unlike `.cancel(ids:)` which requires `ActionResult == Void`,
  /// this variant allows you to return a meaningful result after cancellation.
  ///
  /// Tasks that aren't running are ignored. This is useful for cancelling
  /// a group of related tasks at once.
  ///
  /// ## Example
  /// ```swift
  /// enum MyResult: Sendable {
  ///     case cancelled
  ///     case success(Data)
  /// }
  ///
  /// case .cancelAllDownloads:
  ///     return .cancel(ids: ["download-1", "download-2"], returning: .cancelled)
  /// ```
  ///
  /// - Parameters:
  ///   - ids: An array of task identifiers to cancel
  ///   - result: The result value to return after cancellation
  /// - Returns: A new `ActionTask` that will cancel the specified tasks and return the result
  public static func cancel<ID: TaskID>(
    ids: [ID],
    returning result: ActionResult
  ) -> ActionTask {
    let stringIds = ids.map { $0.taskIdString }
    return ActionTask(operation: .cancel(ids: stringIds, result: result))
  }
}

// MARK: - Composition Methods

extension ActionTask {
  /// Concatenates multiple tasks to run sequentially.
  ///
  /// Tasks execute one after another in order. Each task starts only
  /// after the previous one completes.
  ///
  /// ## Result Handling
  ///
  /// When using `ActionResult != Void`, concatenate returns the **last meaningful result**:
  /// - `.just()` operations return a value
  /// - `.none` operations (Void) are skipped
  /// - The last `.just()` value is returned
  ///
  /// ## Example: Basic Workflow
  /// ```swift
  /// // Multi-step workflow (Void result)
  /// return .concatenate(
  ///     .run { state in
  ///         state.step = 1
  ///         try await Task.sleep(for: .seconds(1))
  ///     },
  ///     .run { state in
  ///         state.step = 2
  ///         try await Task.sleep(for: .seconds(1))
  ///     },
  ///     .run { state in
  ///         state.step = 3
  ///     }
  /// )
  /// ```
  ///
  /// ## Example: With Results
  /// ```swift
  /// // Returns the last result (.updated)
  /// return .concatenate(
  ///     .just(.created(id: "123")),  // Intermediate result
  ///     .run { state in
  ///         // Perform validation
  ///     },
  ///     .just(.updated)  // ← This is returned
  /// )
  /// ```
  ///
  /// - Parameter tasks: Variadic list of tasks to concatenate
  /// - Returns: A single task that runs all tasks sequentially and returns the last meaningful result
  public static func concatenate(_ tasks: ActionTask...) -> ActionTask {
    // Variadic guarantees at least one element at call site
    // Safe to force try because tasks cannot be empty
    // swiftlint:disable:next force_try
    try! concatenate(tasks)
  }

  /// Concatenates an array of tasks to run sequentially.
  ///
  /// Throws `StoreError.noTasksToExecute` if the task array is empty.
  /// This strict behavior helps catch logic errors early.
  ///
  /// ## Example: Dynamic Tasks with Guard
  /// ```swift
  /// let tasks = items.map { item in
  ///   ActionTask.run { state in try await process(item) }
  /// }
  ///
  /// // Explicit handling of empty case
  /// guard !tasks.isEmpty else {
  ///   return .none  // Empty is intentional
  /// }
  ///
  /// return try .concatenate(tasks)
  /// ```
  ///
  /// ## Example: Propagating Error
  /// ```swift
  /// // Let the error propagate if empty is unexpected
  /// return try .concatenate(tasks)  // May throw
  /// ```
  ///
  /// - Parameter tasks: Array of tasks to concatenate (must not be empty)
  /// - Returns: A single task that runs all tasks sequentially
  /// - Throws: `StoreError.noTasksToExecute` if tasks array is empty
  public static func concatenate(_ tasks: [ActionTask]) throws -> ActionTask {
    guard let first = tasks.first else {
      throw StoreError.noTasksToExecute(context: "concatenate(_:)")
    }
    // TCA-style reduce pattern implementing Monoid
    return tasks.dropFirst().reduce(first) { $0.concatenate(with: $1) }
  }

  // MARK: - Internal Binary Operations

  /// Internal method to concatenate this task with another.
  ///
  /// Implements the Monoid identity law: `.concatenate(.just(()), task) == task`
  internal func concatenate(with other: ActionTask) -> ActionTask {
    switch (self.operation, other.operation) {
    case (.just, _):
      // Identity: .just is left identity
      return other
    case (_, .just):
      // Identity: .just is right identity
      return self
    default:
      // Create concatenated task for all other cases
      return ActionTask(operation: .concatenated(self, other))
    }
  }
}

// MARK: - Configuration Methods

extension ActionTask {
  /// Adds error handling to the task.
  ///
  /// The error handler receives both the error and mutable state,
  /// allowing you to update state in response to errors.
  ///
  /// ## Example
  /// ```swift
  /// return .run { state in
  ///   let result = try await riskyOperation()
  ///   state.result = result
  /// }
  /// .catch { error, state in
  ///   state.errorMessage = error.localizedDescription
  ///   state.hasError = true
  /// }
  /// ```
  ///
  /// - Parameter handler: Error handler that receives the error and mutable state
  /// - Returns: A new `ActionTask` with the error handler attached
  public func `catch`(_ handler: @escaping @MainActor (Error, State) -> Void) -> ActionTask {
    switch operation {
    case .run(let id, let name, let op, _, let cancelInFlight, let priority):
      return ActionTask(
        operation: .run(
          id: id,
          name: name,
          operation: op,
          onError: handler,
          cancelInFlight: cancelInFlight,
          priority: priority
        ))
    default:
      return self
    }
  }

  /// Makes this task cancellable with a specific ID.
  ///
  /// This method allows you to:
  /// 1. Assign a specific ID to the task (overriding any auto-generated ID)
  /// 2. Optionally cancel any in-flight task with the same ID before starting this one
  ///
  /// ## Examples
  /// ```swift
  /// // Cancel previous search before starting new one
  /// return .run { state in
  ///   let results = try await search(state.query)
  ///   state.results = results
  /// }
  /// .cancellable(id: "search", cancelInFlight: true)
  ///
  /// // Multiple downloads can run concurrently
  /// return .run { state in
  ///   let data = try await download(url)
  ///   state.downloads[url] = data
  /// }
  /// .cancellable(id: "download-\(url)", cancelInFlight: false)
  /// ```
  ///
  /// - Parameters:
  ///   - id: The identifier for this task
  ///   - cancelInFlight: If `true`, cancels any running task with the same ID before it completes.
  ///                     If `false` (default), waits for the previous task to complete naturally.
  ///                     Note: Due to sequential action processing, tasks with the same ID never run concurrently.
  /// - Returns: A new `ActionTask` with the specified ID and cancellation behavior
  public func cancellable<ID: TaskID>(
    id: ID,
    cancelInFlight: Bool = false
  ) -> ActionTask {
    switch operation {
    case .run(_, let name, let op, let onError, _, let priority):
      let stringId = id.taskIdString
      return ActionTask(
        operation: .run(
          id: stringId,
          name: name,
          operation: op,
          onError: onError,
          cancelInFlight: cancelInFlight,
          priority: priority
        ))
    default:
      return self
    }
  }

  /// Sets the priority for this task.
  ///
  /// Task priority determines the scheduling order. Use higher priorities
  /// for user-facing operations and lower priorities for background work.
  ///
  /// ## Examples
  /// ```swift
  /// // High priority for critical user-facing operations
  /// return .run { state in
  ///   let data = try await api.fetchCritical()
  ///   state.data = data
  /// }
  /// .priority(.high)
  ///
  /// // Background priority for non-urgent work
  /// return .run { state in
  ///   try await analytics.upload()
  /// }
  /// .priority(.background)
  ///
  /// // Combine with other methods
  /// return .run { state in
  ///   let user = try await api.fetchUser()
  ///   state.user = user
  /// }
  /// .priority(.userInitiated)
  /// .cancellable(id: "loadUser", cancelInFlight: true)
  /// .catch { error, state in
  ///   state.errorMessage = "\(error)"
  /// }
  /// ```
  ///
  /// - Parameter priority: The task priority level
  /// - Returns: A new `ActionTask` with the specified priority
  public func priority(_ priority: TaskPriority) -> ActionTask {
    switch operation {
    case .run(let id, let name, let op, let onError, let cancelInFlight, _):
      return ActionTask(
        operation: .run(
          id: id,
          name: name,
          operation: op,
          onError: onError,
          cancelInFlight: cancelInFlight,
          priority: priority
        ))
    default:
      return self
    }
  }
}

// MARK: - Internal Optimization Helpers

extension ActionTask {
  /// Flattens a concatenated task tree into an array of tasks to execute sequentially.
  ///
  /// This optimization converts a left-biased concatenate tree:
  /// ```
  /// concatenated(concatenated(concatenated(a, b), c), d)
  /// ```
  ///
  /// Into a flat array for sequential execution:
  /// ```
  /// [a, b, c, d]  // executed one by one
  /// ```
  ///
  /// ## Performance Benefits
  /// - Reduces function call depth from O(n) to O(1)
  /// - Direct iteration instead of nested recursion
  /// - More efficient for long sequential workflows
  ///
  /// - Returns: Array of tasks to execute sequentially
  internal func flattenConcatenated() -> [ActionTask] {
    switch operation {
    case .concatenated(let left, let right):
      // Recursively flatten both sides
      return left.flattenConcatenated() + right.flattenConcatenated()
    default:
      // Leaf task (run, cancel, or none)
      return [self]
    }
  }
}
