import Flow
import Foundation

/// Application-specific errors for pagination operations.
enum PaginationError: Error, LocalizedError {
  case fetchFailed(underlying: Error)

  var errorDescription: String? {
    switch self {
    case .fetchFailed(let underlying):
      return "Failed to fetch items: \(underlying.localizedDescription)"
    }
  }
}

/// Paginated list feature with infinite scrolling.
///
/// Demonstrates:
/// - Pagination with cursor-based loading
/// - Pull-to-refresh
/// - Load more on scroll
/// - Preventing duplicate fetches
/// - Empty state handling
/// - Error recovery
struct PaginatedListFeature: Feature {
  // MARK: - Dependencies

  let apiClient: PaginatedAPIClient

  // MARK: - State

  @Observable
  final class State {
    var items: [Item] = []

    var isInitialLoading = false  // First load
    var isRefreshing = false  // Pull-to-refresh
    var isLoadingMore = false  // Loading next page

    var nextCursor: String?  // Pagination cursor
    var hasMore = true  // More pages available

    var error: PaginationError?

    init(
      items: [Item] = [],
      hasMore: Bool = true
    ) {
      self.items = items
      self.hasMore = hasMore
    }
  }

  // MARK: - Actions

  enum Action: Sendable {
    case initialLoad
    case refresh
    case loadMore
    case loadSucceeded(items: [Item], nextCursor: String?, hasMore: Bool)
    case loadFailed(Error)
  }

  // MARK: - Action Handler

  // swiftlint:disable function_body_length
  func handle() -> ActionHandler<Action, State, Void> {
    ActionHandler { [apiClient] action, state in
      switch action {
      case .initialLoad:
        // Prevent duplicate initial loads
        guard !state.isInitialLoading else { return .none }

        state.isInitialLoading = true
        state.error = nil

        return .run { state in
          do {
            let response = try await apiClient.fetchPage(cursor: nil)

            state.items = response.items
            state.nextCursor = response.nextCursor
            state.hasMore = response.hasMore
            state.isInitialLoading = false
            state.error = nil
          } catch {
            throw PaginationError.fetchFailed(underlying: error)
          }
        }
        .cancellable(id: "fetch-page", cancelInFlight: true)
        .catch { error, state in
          state.isInitialLoading = false
          if let paginationError = error as? PaginationError {
            state.error = paginationError
          } else {
            state.error = .fetchFailed(underlying: error)
          }
        }

      case .refresh:
        // Prevent duplicate refreshes
        guard !state.isRefreshing else { return .none }

        state.isRefreshing = true
        state.error = nil

        return .run { state in
          do {
            let response = try await apiClient.fetchPage(cursor: nil)

            state.items = response.items
            state.nextCursor = response.nextCursor
            state.hasMore = response.hasMore
            state.isRefreshing = false
            state.error = nil
          } catch {
            throw PaginationError.fetchFailed(underlying: error)
          }
        }
        .cancellable(id: "fetch-page", cancelInFlight: true)
        .catch { error, state in
          state.isRefreshing = false
          if let paginationError = error as? PaginationError {
            state.error = paginationError
          } else {
            state.error = .fetchFailed(underlying: error)
          }
        }

      case .loadMore:
        // Prevent loading if already loading or no more pages
        guard !state.isLoadingMore,
          !state.isInitialLoading,
          !state.isRefreshing,
          state.hasMore,
          let cursor = state.nextCursor
        else {
          return .none
        }

        state.isLoadingMore = true
        state.error = nil

        return .run { state in
          do {
            let response = try await apiClient.fetchPage(cursor: cursor)

            state.items.append(contentsOf: response.items)
            state.nextCursor = response.nextCursor
            state.hasMore = response.hasMore
            state.isLoadingMore = false
            state.error = nil
          } catch {
            throw PaginationError.fetchFailed(underlying: error)
          }
        }
        .cancellable(id: "fetch-page", cancelInFlight: true)
        .catch { error, state in
          state.isLoadingMore = false
          if let paginationError = error as? PaginationError {
            state.error = paginationError
          } else {
            state.error = .fetchFailed(underlying: error)
          }
        }

      case .loadSucceeded(let items, let nextCursor, let hasMore):
        state.items.append(contentsOf: items)
        state.nextCursor = nextCursor
        state.hasMore = hasMore
        state.isLoadingMore = false
        state.error = nil
        return .none

      case .loadFailed(let error):
        state.isInitialLoading = false
        state.isRefreshing = false
        state.isLoadingMore = false

        if let vfError = error as? FlowError {
          state.error = vfError
        } else {
          state.error = .networkError(underlying: error)
        }

        return .none
      }
    }
  }
  // swiftlint:enable function_body_length
}

// MARK: - Supporting Types

struct PaginatedResponse: Sendable {
  let items: [Item]
  let nextCursor: String?
  let hasMore: Bool
}

protocol PaginatedAPIClient: Sendable {
  func fetchPage(cursor: String?) async throws -> PaginatedResponse
}

// MARK: - Mock Paginated API Client

struct MockPaginatedAPIClient: PaginatedAPIClient {
  let pageSize: Int
  let totalPages: Int

  init(pageSize: Int = 20, totalPages: Int = 5) {
    self.pageSize = pageSize
    self.totalPages = totalPages
  }

  func fetchPage(cursor: String?) async throws -> PaginatedResponse {
    // Simulate network delay
    try await Task.sleep(for: .milliseconds(300))

    let currentPage = cursor.flatMap { Int($0) } ?? 0
    let nextPage = currentPage + 1

    // Generate items for this page
    let startIndex = currentPage * pageSize
    let endIndex = min(startIndex + pageSize, totalPages * pageSize)

    let items = (startIndex..<endIndex).map { index in
      Item(id: "\(index)", name: "Item \(index)")
    }

    let hasMore = nextPage < totalPages
    let nextCursor = hasMore ? "\(nextPage)" : nil

    return PaginatedResponse(
      items: items,
      nextCursor: nextCursor,
      hasMore: hasMore
    )
  }
}
