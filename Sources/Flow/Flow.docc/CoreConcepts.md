# Core Concepts

Learn how unidirectional data flow and core components work.

## Overview

This guide explains Flow's design philosophy and key features. You'll learn about unidirectional data flow, why Flow avoids global stores, result-returning actions, and other important concepts.

## Unidirectional Data Flow

Flow adopts unidirectional data flow. All state changes occur through actions, allowing you to track how state evolves.

![Flow Architecture Diagram](flow-diagram.svg)

### Flow of Execution

1. User taps a button
2. View sends an action through the store
3. Handler updates state
4. SwiftUI detects state changes
5. View re-renders automatically

## Key Features

### No Global Store

Each view holds its own state with `@State`.

```swift
import SwiftUI
import Flow

struct CounterView: View {
    @State private var store = Store(
        initialState: .init(),
        feature: CounterFeature()
    )

    var body: some View {
        VStack {
            Text("\(store.state.count)")
            Button("Increment") {
                store.send(.increment)
            }
        }
    }
}
```

- State scope matches the view lifecycle
- Reduces the need to manage global state

### Result-Returning Actions

Actions can return results through `ActionTask`. The result type (`ActionResult`) can be defined for each Feature.

**Basic example:**

```swift
import SwiftUI
import Flow

struct LoginFeature: Feature {
    @Observable
    final class State {
        var username = ""
        var password = ""
    }

    enum Action: Sendable {
        case login
    }

    enum ActionResult: Sendable {
        case success
        case invalidCredentials
        case networkError
    }

    func handle() -> ActionHandler<Action, State, ActionResult> {
        ActionHandler { action, state in
            switch action {
            case .login:
                if state.username.isEmpty || state.password.isEmpty {
                    return .just(.invalidCredentials)  // Return result immediately
                }
                return .run { state in  // Async work with result
                    do {
                        try await api.login(state.username, state.password)
                        return .success
                    } catch {
                        return .networkError
                    }
                }
            }
        }
    }
}

struct LoginView: View {
    @State private var store = Store(
        initialState: .init(),
        feature: LoginFeature()
    )

    var body: some View {
        VStack {
            TextField("Username", text: $store.state.username)
            SecureField("Password", text: $store.state.password)
            Button("Login") {
                Task {
                    let result = await store.send(.login).value
                    switch result {
                    case .success(.success):
                        print("Navigate to home")
                    case .success(.invalidCredentials):
                        print("Show error: Invalid credentials")
                    case .success(.networkError):
                        print("Show error: Network error")
                    case .failure(let error):
                        print("Unexpected error: \(error)")
                    }
                }
            }
        }
    }
}
```

**Key concepts:**
- **ActionResult** - Define custom result types for your Feature
- **`.just(result)`** - Return results immediately (synchronous)
- **`.run { ... return result }`** - Return results after async work
- **`await store.send().value`** - Wait for and receive the result
- **`Result<ActionResult, Error>`** - Results are wrapped in Swift's Result type

**Use cases for ActionResult:**
- Form validation with specific error types
- Navigation decisions based on action outcomes
- Showing different toasts based on success/failure patterns

For parent-child communication patterns and more advanced examples, see <doc:PracticalGuide#Parent-Child-Communication>.

### @Observable Support

Uses SwiftUI's standard **@Observable** instead of `@ObservableObject` or `@Published`.

```swift
import Observation

@Observable
final class State {
    var count = 0
}
```

- No Combine dependency
- Reduced code
- Integrates with SwiftUI's standard APIs

### Swift 6 Concurrency

Supports **Swift 6 Concurrency**.

A Swift 6 feature that allows setting default actor isolation for an entire module. Flow assumes `defaultIsolation(MainActor.self)`, eliminating the need for explicit `@MainActor` annotations.

```swift
.defaultIsolation(MainActor.self)
```

This ensures all operations run on the MainActor, with **compile-time data race detection**. A data race occurs when multiple threads access the same memory simultaneously and at least one performs a write.

```swift
import Flow

func handle() -> ActionHandler<Action, State, Void> {
    ActionHandler { action, state in
        switch action {
        case .increment:
            state.count += 1  // Synchronous operations are safe
            return .none

        case .loadData:
            return .run { state in
                let data = try await api.fetch()
                state.data = data  // State mutations safe even in async operations
            }
        }
    }
}
```

- Provides thread-safety
- Native `async/await` support

### Observable Actions

Flow uses **middleware** to observe actions.

```swift
import Flow

struct AnalyticsMiddleware: BeforeActionMiddleware {
    let id = "Analytics"
    let analytics: AnalyticsService

    func beforeAction<Action, State>(_ action: Action, state: State) async {
        analytics.track(String(describing: action))
    }
}

func handle() -> ActionHandler<Action, State, Void> {
    ActionHandler { action, state in
        // ...
    }
    .use(LoggingMiddleware(category: "Counter"))
    .use(AnalyticsMiddleware(analytics: .shared))
}
```

- Observe actions in one place
- Use for logging, analytics, and debugging

## Next Steps

Now that you understand the core concepts, let's learn about each element in detail:

- **Next**: <doc:CoreElements>

**Recommended learning path**:
1. <doc:Middleware>
2. <doc:PracticalGuide>

## See Also

- ``Store``
- ``Feature``
- ``ActionHandler``
- ``ActionTask``
