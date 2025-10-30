# Practical Guide

Learn patterns and techniques for application development.

## Overview

Common patterns with code examples. Covers synchronous processing, async processing, task cancellation, parallel processing, continuous data fetching, parent-child communication, middleware, and testing.

## Synchronous Processing

Synchronous state changes update state directly in the handler and return `.none`. Ideal for immediate UI event responses.

```swift
import SwiftUI
import Flow

struct CounterFeature: Feature {
    @Observable
    final class State {
        var count = 0
    }

    enum Action: Sendable {
        case increment
    }

    func handle() -> ActionHandler<Action, State, Void> {
        ActionHandler { action, state in
            switch action {
            case .increment:
                state.count += 1
                return .none
            }
        }
    }
}

struct CounterView: View {
    @State private var store = Store(
        initialState: .init(),
        feature: CounterFeature()
    )

    var body: some View {
        VStack(spacing: 20) {
            Text("\(store.state.count)")
                .font(.largeTitle)

            Button("Increment") {
                store.send(.increment)
            }
        }
    }
}
```

## Async Processing

Use `.run` for async operations like API calls. Combine with `.catch` to update state on failure.

```swift
import Flow

func handle() -> ActionHandler<Action, State, Void> {
    ActionHandler { action, state in
        switch action {
        case .loadData:
            state.isLoading = true
            state.errorMessage = nil
            return .run { state in
                let data = try await api.fetch()
                state.data = data
                state.isLoading = false
            }
            .catch { error, state in
                state.errorMessage = error.localizedDescription
                state.isLoading = false
            }
        }
    }
}
```

## Task Cancellation

Cancel previous requests with `.cancellable(id:cancelInFlight:)` for user input operations like search.

**Understanding `cancelInFlight`:**
- `true` - Cancels any running task with the same ID before starting the new one
- `false` - Allows multiple tasks with the same ID to run concurrently

```swift
import Flow

func handle() -> ActionHandler<Action, State, Void> {
    ActionHandler { action, state in
        switch action {
        case .search(let query):
            state.isSearching = true
            return .run { state in
                try await Task.sleep(for: .milliseconds(300))
                let results = try await api.search(query)
                state.results = results
                state.isSearching = false
            }
            .cancellable(id: "search", cancelInFlight: true)
            .catch { error, state in
                state.isSearching = false
                // Note: Cancellation errors are handled automatically,
                // only explicit errors from api.search() reach here
                if error is CancellationError {
                    // Task was cancelled, no action needed
                } else {
                    state.errorMessage = error.localizedDescription
                }
            }

        case .cancelSearch:
            state.isSearching = false
            return .cancel(id: "search")
        }
    }
}
```

## Parallel Processing

Execute multiple async operations concurrently with `async let`.

```swift
import Flow

func handle() -> ActionHandler<Action, State, Void> {
    ActionHandler { action, state in
        switch action {
        case .loadAll:
            state.isLoading = true
            return .run { state in
                async let users = api.fetchUsers()
                async let posts = api.fetchPosts()

                state.users = try await users
                state.posts = try await posts
                state.isLoading = false
            }
            .catch { error, state in
                state.isLoading = false
                state.errorMessage = "Failed to load data: \(error.localizedDescription)"
            }
        }
    }
}
```

## Task Priority

Set task priority to control how the system schedules async operations.

**Priority levels:**

| Priority | When to Use | Example Use Cases |
|----------|-------------|-------------------|
| `.high` | User is actively waiting for results | Critical data loading, search results |
| `.userInitiated` | User-triggered operations | Button actions, form submissions |
| `.utility` | Improve UX but not urgent | Prefetching, caching next page |
| `.background` | Can run anytime | Analytics uploads, logs, cleanup |

**Example:**

```swift
import Flow

func handle() -> ActionHandler<Action, State, Void> {
    ActionHandler { action, state in
        switch action {
        case .loadCriticalData:
            // User is waiting for this data
            return .run { state in
                let data = try await api.fetchCriticalData()
                state.data = data
            }
            .priority(.high)

        case .uploadAnalytics:
            // Background task, can run anytime
            return .run { state in
                try await analytics.upload(state.events)
                state.events.removeAll()
            }
            .priority(.background)
        }
    }
}
```

> Note: Priority affects scheduling but doesn't guarantee execution order. Use `.concatenate` when strict ordering is required.

## Method Chaining

Combine multiple methods to set priority, cancellation, error handling, and more on tasks.

```swift
import Flow

return .run { state in
    let user = try await api.fetchUser()
    state.user = user
}
.priority(.userInitiated)
.cancellable(id: "loadUser", cancelInFlight: true)
.catch { error, state in
    state.errorMessage = error.localizedDescription
}
```

## Data Fetching with AsyncStream

Use AsyncStream for continuous data like location updates. Receive values with `for await` and update state.

> Note: This example assumes an existing LocationManager provides AsyncStream<CLLocation> via the `updates` property.

```swift
import Flow
import CoreLocation

func handle() -> ActionHandler<Action, State, Void> {
    ActionHandler { action, state in
        switch action {
        case .startLocationUpdates:
            return .run { state in
                for await location in locationManager.updates {
                    state.latitude = location.coordinate.latitude
                    state.longitude = location.coordinate.longitude
                }
            }
            .cancellable(id: "location-updates", cancelInFlight: true)

        case .stopLocationUpdates:
            return .cancel(id: "location-updates")
        }
    }
}
```

## Parent-Child Communication

Enable view coordination by having parent views receive action results from child views. Pass results through callback functions.

> Note: The `navigator` in this example is an external navigation system not included in Flow. Replace with your project's navigation approach.

```swift
import SwiftUI
import Flow

// Parent view
struct ParentView: View {
    var body: some View {
        ChildView { result in
            switch result {
            case .valid:
                print("Valid")
            case .invalid(let message):
                print("Invalid: \(message)")
            }
        }
    }
}

// Child view
struct ChildView: View {
    @State private var store = Store(
        initialState: .init(),
        feature: ChildFeature()
    )
    let onValidate: (ChildFeature.ValidationResult) -> Void

    var body: some View {
        VStack {
            TextField("Input", text: $store.state.input)
            Button("Validate") {
                Task {
                    let result = await store.send(.validate).value
                    switch result {
                    case .success(let validationResult):
                        onValidate(validationResult)
                    case .failure(let error):
                        print("Validation error: \(error)")
                        // Handle unexpected errors (network issues, etc.)
                    }
                }
            }
        }
    }
}

// Child feature
struct ChildFeature: Feature {
    @Observable
    final class State {
        var input = ""
    }

    enum Action: Sendable {
        case validate
    }

    enum ValidationResult: Sendable {
        case valid
        case invalid(String)
    }

    func handle() -> ActionHandler<Action, State, ValidationResult> {
        ActionHandler { action, state in
            switch action {
            case .validate:
                if state.input.isEmpty {
                    return .just(.invalid("Required"))
                }
                return .just(.valid)
            }
        }
    }
}
```

---

## Middleware

**Using middleware:**

```swift
func handle() -> ActionHandler<Action, State, Void> {
    ActionHandler { action, state in
        // Action processing logic
    }
    .use(LoggingMiddleware(category: "MyFeature"))
}
```

**Multiple middleware:**

```swift
func handle() -> ActionHandler<Action, State, Void> {
    ActionHandler { action, state in
        // Action processing logic
    }
    .use(LoggingMiddleware(category: "MyFeature"))
    .use(AnalyticsMiddleware(analytics: .shared))
    .use(ErrorReportingMiddleware(reporter: .production))
}
```

**Custom middleware:**

```swift
import Flow

struct TimingMiddleware: BeforeActionMiddleware, AfterActionMiddleware {
    let id = "Timing"

    func beforeAction<Action, State>(_ action: Action, state: State) async {
        print("⏱️ Started: \(action)")
    }

    func afterAction<Action, State>(
        _ action: Action,
        state: State,
        result: ActionTask<Action, State, Void>
    ) async {
        print("✅ Completed: \(action)")
    }
}
```

---

## Testing

**Testing error handling:**

```swift
import Testing
import Flow

@MainActor
@Test func loadDataFailure() async {
    let store = Store(
        initialState: .init(),
        feature: DataFeature(apiClient: FailingAPIClient())
    )

    await store.send(.loadData).value

    #expect(store.state.errorMessage != nil)
    #expect(!store.state.isLoading)
}
```

**Testing task cancellation:**

```swift
import Testing
import Flow

@MainActor
@Test func searchCancellation() async {
    let store = Store(
        initialState: .init(),
        feature: SearchFeature()
    )

    let task1 = store.send(.search("first"))
    let task2 = store.send(.search("second"))

    await task2.value

    #expect(task1.isCancelled)
    #expect(store.state.results.contains("second"))
}
```

---

## See Also

- <doc:GettingStarted>
- <doc:CoreConcepts>
- <doc:CoreElements>
- <doc:Middleware>
