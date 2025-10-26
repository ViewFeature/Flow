import Flow
import SwiftUI

/// SwiftUI view demonstrating infinite scrolling with PaginatedListFeature.
struct PaginatedListView: View {
  @State private var store = Store(
    initialState: PaginatedListFeature.State(),
    feature: PaginatedListFeature(
      apiClient: MockPaginatedAPIClient()
    )
  )

  var body: some View {
    NavigationStack {
      ZStack {
        if store.state.isInitialLoading {
          // Initial loading state
          ProgressView("Loading...")
        } else if store.state.items.isEmpty {
          // Empty state
          EmptyStateView {
            store.send(.initialLoad)
          }
        } else {
          // List with items
          ScrollView {
            LazyVStack(spacing: 0) {
              ForEach(store.state.items) { item in
                ItemRow(item: item)
                  .onAppear {
                    // Load more when approaching the end
                    if item.id == store.state.items.last?.id {
                      store.send(.loadMore)
                    }
                  }
              }

              // Loading more indicator
              if store.state.isLoadingMore {
                ProgressView()
                  .frame(maxWidth: .infinity)
                  .padding()
              }

              // End of list indicator
              if !store.state.hasMore && !store.state.items.isEmpty {
                Text("No more items")
                  .font(.caption)
                  .foregroundColor(.secondary)
                  .frame(maxWidth: .infinity)
                  .padding()
              }
            }
          }
          .refreshable {
            // Pull-to-refresh
            await store.send(.refresh).value
          }
        }
      }
      .navigationTitle("Infinite Scroll")
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          if store.state.isRefreshing {
            ProgressView()
          }
        }
      }
      .alert(
        "Error",
        isPresented: .constant(store.state.error != nil),
        presenting: store.state.error
      ) { _ in
        Button("Retry") {
          if store.state.items.isEmpty {
            store.send(.initialLoad)
          } else {
            store.send(.loadMore)
          }
        }
        Button("Cancel", role: .cancel) {
          store.state.error = nil
        }
      } message: { error in
        if let description = error.errorDescription {
          Text(description)
        }
      }
    }
    .onAppear {
      if store.state.items.isEmpty && !store.state.isInitialLoading {
        store.send(.initialLoad)
      }
    }
  }
}

// MARK: - Subviews

struct ItemRow: View {
  let item: Item

  var body: some View {
    HStack {
      Circle()
        .fill(Color.blue.opacity(0.3))
        .frame(width: 40, height: 40)
        .overlay(
          Text(item.id)
            .font(.caption)
            .foregroundColor(.blue)
        )

      VStack(alignment: .leading, spacing: 4) {
        Text(item.name)
          .font(.headline)

        Text("ID: \(item.id)")
          .font(.caption)
          .foregroundColor(.secondary)
      }

      Spacer()

      Image(systemName: "chevron.right")
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .padding()
    .background(Color(UIColor.secondarySystemBackground))
    .cornerRadius(8)
    .padding(.horizontal)
    .padding(.vertical, 4)
  }
}

struct EmptyStateView: View {
  let onRetry: () -> Void

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "tray")
        .font(.system(size: 64))
        .foregroundColor(.secondary)

      Text("No items yet")
        .font(.title2)
        .fontWeight(.semibold)

      Text("Tap the button below to load items")
        .font(.caption)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)

      Button("Load Items") {
        onRetry()
      }
      .buttonStyle(.borderedProminent)
    }
    .padding()
  }
}

// MARK: - Preview

#Preview {
  PaginatedListView()
}
