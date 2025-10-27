import Foundation

/// Manages asynchronous task execution and lifecycle within the Store.
///
/// `TaskManager` is a **MainActor-isolated** class that provides robust task management
/// with automatic cleanup and cancellation support. All task operations execute on the
/// MainActor, ensuring thread-safe state access and seamless SwiftUI integration.
///
/// ## Key Features
/// - **MainActor Isolation**: All operations run on MainActor for thread-safe execution
/// - Automatic task cleanup on completion or cancellation
/// - Task identification and tracking by unique IDs
/// - Concurrent task execution with individual cancellation
/// - Error handling delegation to Store
///
/// ## Architecture Role
/// TaskManager is a core component of the Store's task execution system. It handles:
/// - Task lifecycle management (start, track, cancel, cleanup)
/// - Concurrent task coordination
/// - Memory safety through weak references
///
/// ## Usage
/// TaskManager is typically used internally by ``Store``. Tasks are automatically
/// cancelled when the TaskManager is deallocated (e.g., when Store is released).
/// ```swift
/// let taskManager = TaskManager()
///
/// // Execute a task with automatic tracking
/// taskManager.executeTask(
///   id: "fetchData",
///   operation: {
///     let data = try await api.fetchData()
///     print("Data loaded: \(data)")
///   },
///   onError: { error in
///     print("Failed: \(error)")
///   }
/// )
///
/// // Tasks are automatically cancelled when taskManager is deallocated
/// ```
///
/// ## Task Lifecycle
/// 1. **Start**: Task is created and added to tracking dictionary
/// 2. **Execute**: Operation runs asynchronously on MainActor
/// 3. **Complete**: Task automatically removes itself from tracking
/// 4. **Error**: Error handler is called if provided
///
/// ## Memory Management
/// TaskManager uses weak references to prevent retain cycles and automatically
/// cleans up completed tasks using a deferred cleanup strategy.
///
/// ## Topics
/// ### Creating a Manager
/// - ``init()``
///
/// ### Task Execution
/// - ``executeTask(id:operation:onError:priority:)``
@MainActor
public final class TaskManager {
  private var runningTasks: [String: Task<Void, Never>] = [:]

  /// Creates a new TaskManager instance.
  public init() {}

  /// Automatically cancels all running tasks when TaskManager is deallocated.
  ///
  /// This ensures proper resource cleanup when the Store (and its TaskManager)
  /// is released, such as when a View is dismissed or a feature scope ends.
  ///
  /// ## Design Rationale
  /// - **Automatic cleanup**: Prevents orphaned tasks from consuming resources
  /// - **Memory safety**: Task lifetime tied to TaskManager lifetime
  /// - **Predictable behavior**: No manual cleanup needed
  ///
  /// ## Implementation Note
  /// Uses `isolated deinit` (SE-0371) to safely access MainActor-isolated state.
  /// The runtime automatically hops onto the MainActor's executor before running
  /// this deinit, ensuring thread-safe access to `runningTasks`.
  isolated deinit {
    runningTasks.values.forEach { $0.cancel() }
    runningTasks.removeAll()
  }

  /// Executes an asynchronous operation as a tracked task and returns the Task.
  ///
  /// Creates and tracks a new task with automatic cleanup. If a task with the same
  /// ID already exists, the old task is cancelled before starting the new one.
  /// The task runs on the MainActor and handles errors through the provided handler.
  ///
  /// ## Design Decision: Why No ExecutionPolicy Abstraction?
  ///
  /// The cancellation behavior (lines 123-127) is intentionally **not** abstracted into
  /// a policy pattern. This is a deliberate design choice:
  ///
  /// 1. **User Control via ActionTask API**: Cancellation policy is already controlled by users
  ///    through `ActionTask.cancellable(id:cancelInFlight:)`. The TaskManager respects
  ///    decisions made at the ActionTask level (see Store.executeTask line 216-218).
  ///
  /// 2. **Safety Net**: The cancellation here (line 124-126) serves as a safety mechanism
  ///    for edge cases during `.merge()` parallel execution, not as a configurable policy.
  ///
  /// 3. **YAGNI**: Adding an ExecutionPolicy abstraction would introduce:
  ///    - Dual control mechanisms (ActionTask.cancelInFlight + ExecutionPolicy)
  ///    - Confusion about precedence and interaction
  ///    - Unnecessary complexity without concrete use cases
  ///
  /// 4. **Single Responsibility**: TaskManager's job is low-level task lifecycle management
  ///    (create, track, cleanup), not policy decisions. Policy is determined at the
  ///    ActionTask/Store orchestration layer.
  ///
  /// The current design provides all necessary control through the existing ActionTask API
  /// while keeping TaskManager focused on its core responsibility.
  ///
  /// - Parameters:
  ///   - id: Unique identifier for the task (string representation)
  ///   - name: Optional human-readable name for the task (useful for debugging and profiling)
  ///   - operation: The asynchronous operation to execute
  ///   - onError: Optional error handler called if the operation throws
  ///   - priority: Optional task priority (defaults to nil, using system default)
  /// - Returns: The created Task that can be awaited for completion
  ///
  /// ## Example
  /// ```swift
  /// let task = taskManager.executeTask(
  ///   id: "loadProfile",
  ///   name: "🔄 Load user profile",
  ///   operation: {
  ///     let profile = try await api.fetchProfile()
  ///     await store.send(.profileLoaded(profile))
  ///   },
  ///   onError: { error in
  ///     await store.send(.profileLoadFailed(error))
  ///   }
  /// )
  ///
  /// // Optionally wait for completion
  /// await task.value
  /// ```
  ///
  /// - Note: Tasks automatically remove themselves from tracking upon completion
  @discardableResult
  public func executeTask(
    id: String,
    name: String? = nil,
    operation: @escaping () async throws -> Void,
    onError: ((Error) async -> Void)?,
    priority: TaskPriority? = nil
  ) -> Task<Void, Never> {
    // Cancel existing task with same ID (handles edge case in .merge() parallel execution)
    if let existingTask = runningTasks[id] {
      existingTask.cancel()
      runningTasks.removeValue(forKey: id)
    }

    // Use [weak self] to prevent retain cycle (TaskManager ← runningTasks ← Task)
    // Ensures deinit runs when Store deallocates, cancelling all tasks
    let task = Task(name: name, priority: priority) { @MainActor [weak self] in
      guard let self else { return }

      // Defer ensures cleanup happens exactly once, regardless of how the task completes
      // (normal completion, error, or cancellation)
      defer {
        runningTasks.removeValue(forKey: id)
      }

      do {
        try await operation()
      } catch {
        if let errorHandler = onError {
          await errorHandler(error)
        }
      }
    }

    runningTasks[id] = task
    return task
  }

  /// Cancels tasks by their identifiers and removes them from tracking.
  ///
  /// Used internally by ``Store`` when processing `.cancels(ids:)` action tasks.
  /// Tasks are removed immediately; the defer block in `executeTask()` safely handles duplicate removal.
  ///
  /// - Parameter ids: The task identifiers to cancel
  ///
  /// - Note: This is an internal API. Use Actions (e.g., `return .cancel(id: "taskId")`) instead.
  internal func cancelTasks(ids: [String]) {
    for id in ids {
      runningTasks[id]?.cancel()
      runningTasks.removeValue(forKey: id)
    }
  }
}
