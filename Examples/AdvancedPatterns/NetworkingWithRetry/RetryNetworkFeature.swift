import Flow
import Foundation

/// Application-specific errors for retry networking.
enum RetryError: Error, LocalizedError {
  case maxRetriesExceeded(attempts: Int)
  case networkFailure(underlying: Error)

  var errorDescription: String? {
    switch self {
    case .maxRetriesExceeded(let attempts):
      return "Failed after \(attempts) retry attempts"
    case .networkFailure(let underlying):
      return "Network error: \(underlying.localizedDescription)"
    }
  }
}

/// Advanced networking feature with exponential backoff retry logic.
///
/// Demonstrates:
/// - Retry with exponential backoff
/// - Maximum retry attempts
/// - Error handling with custom error types
/// - Task cancellation
/// - Loading states during retries
struct RetryNetworkFeature: Feature {
  // MARK: - Dependencies

  let apiClient: APIClient
  let maxRetries: Int
  let baseDelay: Duration

  init(
    apiClient: APIClient,
    maxRetries: Int = 3,
    baseDelay: Duration = .milliseconds(500)
  ) {
    self.apiClient = apiClient
    self.maxRetries = maxRetries
    self.baseDelay = baseDelay
  }

  // MARK: - State

  @Observable
  final class State {
    var data: [Item]?
    var isLoading = false
    var error: RetryError?

    // Retry tracking
    var retryCount = 0
    var retryDelay: Duration?

    init(
      data: [Item]? = nil,
      isLoading: Bool = false,
      error: RetryError? = nil
    ) {
      self.data = data
      self.isLoading = isLoading
      self.error = error
    }
  }

  // MARK: - Actions

  enum Action: Sendable {
    case fetchData
    case retryFetch
    case cancelFetch
    case fetchSucceeded([Item])
    case fetchFailed(Error)
  }

  // MARK: - Action Handler

  func handle() -> ActionHandler<Action, State, Void> {
    ActionHandler { [self] action, state in
      switch action {
      case .fetchData:
        state.isLoading = true
        state.error = nil
        state.retryCount = 0

        return performFetchWithRetry(state: state)

      case .retryFetch:
        guard state.retryCount < maxRetries else {
          state.error = .maxRetriesExceeded(attempts: maxRetries)
          state.isLoading = false
          return .none
        }

        state.retryCount += 1
        state.error = nil

        return performFetchWithRetry(state: state)

      case .cancelFetch:
        state.isLoading = false
        state.error = nil
        state.retryCount = 0
        return .cancel(id: "fetch-data")

      case .fetchSucceeded(let items):
        state.data = items
        state.isLoading = false
        state.error = nil
        state.retryCount = 0
        return .none

      case .fetchFailed(let error):
        state.isLoading = false

        if state.retryCount < maxRetries {
          // Calculate exponential backoff delay
          let delay = calculateBackoffDelay(attempt: state.retryCount)
          state.retryDelay = delay

          // Schedule retry
          return .concatenate(
            // Wait with delay
            .run { _ in
              try await Task.sleep(for: delay)
            },

            // Then retry
            .run { _ in
              // This will trigger .retryFetch action
              // In real app, use store.send(.retryFetch) or similar
            }
          )
        } else {
          // Max retries exceeded
          state.error = .networkFailure(underlying: error)
          return .none
        }
      }
    }
  }

  // MARK: - Private Helpers

  private func performFetchWithRetry(state: State) -> ActionTask<Action, State, Void> {
    .run { [apiClient] state in
      do {
        let items = try await apiClient.fetchItems()
        state.data = items
        state.isLoading = false
        state.error = nil
        state.retryCount = 0
      } catch {
        if state.retryCount < maxRetries {
          state.retryCount += 1

          // Calculate exponential backoff delay
          let delay = calculateBackoffDelay(attempt: state.retryCount)
          state.retryDelay = delay

          // Wait with backoff
          try await Task.sleep(for: delay)

          // Retry recursively
          try await performFetch(state: state)
        } else {
          throw RetryError.maxRetriesExceeded(attempts: maxRetries)
        }
      }
    }
    .cancellable(id: "fetch-data", cancelInFlight: true)
    .catch { error, state in
      state.isLoading = false
      if let retryError = error as? RetryError {
        state.error = retryError
      } else {
        state.error = .networkFailure(underlying: error)
      }
    }
  }

  private func performFetch(state: State) async throws {
    let items = try await apiClient.fetchItems()
    state.data = items
    state.isLoading = false
    state.error = nil
    state.retryCount = 0
  }

  private func calculateBackoffDelay(attempt: Int) -> Duration {
    // Exponential backoff: baseDelay * 2^attempt
    let multiplier = Int(pow(2.0, Double(attempt)))
    let nanoseconds =
      baseDelay.components.seconds * 1_000_000_000
      + baseDelay.components.attoseconds / 1_000_000_000
    return Duration(
      secondsComponent: nanoseconds * Int64(multiplier) / 1_000_000_000,
      attosecondsComponent: 0
    )
  }
}

// MARK: - Supporting Types

struct Item: Identifiable, Sendable {
  let id: String
  let name: String
}

protocol APIClient: Sendable {
  func fetchItems() async throws -> [Item]
}

// MARK: - Mock API Client

struct MockAPIClient: APIClient {
  var shouldFail: Bool = false
  var failureCount: Int = 0
  private let attemptCounter = AttemptCounter()

  func fetchItems() async throws -> [Item] {
    let attempt = attemptCounter.increment()

    // Simulate network delay
    try await Task.sleep(for: .milliseconds(200))

    if shouldFail && attempt <= failureCount {
      throw APIError.networkFailure
    }

    return [
      Item(id: "1", name: "Item 1"),
      Item(id: "2", name: "Item 2"),
      Item(id: "3", name: "Item 3")
    ]
  }

  enum APIError: Error {
    case networkFailure
  }
}

// Thread-safe attempt counter
final class AttemptCounter: @unchecked Sendable {
  private var value = 0
  private let lock = NSLock()

  func increment() -> Int {
    lock.lock()
    defer { lock.unlock() }
    value += 1
    return value
  }
}
