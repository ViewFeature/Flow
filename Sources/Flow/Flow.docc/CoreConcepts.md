# Core Concepts

Learn Flow's design philosophy through five core principles.

## Overview

This guide explains Flow's design philosophy and key features. Flow combines the clarity of unidirectional data flow with SwiftUI's modern capabilities—Observation and Swift 6 Concurrency—to provide a simple yet robust state management solution.

## The 5 Core Principles

### 1. Unidirectional Data Flow: Predictable State Management

Flow adopts unidirectional data flow, inspired by Redux and ReSwift. All state changes flow in one direction, making your application's behavior predictable and easy to reason about.

```
Action → Handler → State → View
  ↑                           ↓
  └──────── User Event ────────┘
```

![Flow Architecture Diagram](flow-diagram.svg)

**How it works:**

1. **View** - User event occurs (button tap, etc.)
2. **Action** - View sends an action to the store (`store.send(.increment)`)
3. **Handler** - ActionHandler processes the action and updates state
4. **State** - State changes automatically propagate to the view (`@Observable`)
5. **View** - UI updates to reflect the new state

```swift
// 1. View event occurs
Button("Load") {
    store.send(.load)  // 2. Send action
}

// 3. Handler processes action
ActionHandler { action, state in
    switch action {
    case .load:
        state.isLoading = true  // 4. Update state
        return .run { state in
            let data = try await api.fetch()
            state.data = data  // 4. Update state
        }
    }
}

// 5. View automatically updates (@Observable)
if store.state.isLoading {
    ProgressView()
}
```

**Benefits:**
- **Predictable** - Data flows in one direction, making it easy to trace
- **Debuggable** - Clear visibility into which actions modify which state
- **Testable** - Well-defined inputs (actions) and outputs (state)

### 2. View-Local State: Aligned with SwiftUI Philosophy

In SwiftUI, **only Views form a tree structure**:

```
NavigationStack (View)
  └─ ListScreen (View)
       └─ DetailScreen (View)
```

Parent views → child views → grandchild views form a hierarchy, but state is held locally by each view using `@State`.

**The Problem with Many State Management Libraries:**

Many libraries try to create store hierarchies (parent store → child store → grandchild store). This deviates from SwiftUI's philosophy and adds unnecessary complexity.

**Flow's Approach:**

Following SwiftUI's standard, each view holds its own independent store. There's no parent-child relationship between stores:

```swift
import SwiftUI
import Flow

struct UserListView: View {
    // Each view holds its own independent store
    @State private var store = Store(
        initialState: UserFeature.State(),
        feature: UserFeature()
    )

    var body: some View {
        List(store.state.users) { user in
            Text(user.name)
        }
        .onAppear {
            store.send(.load)
        }
    }
}
```

**Benefits:**
- **Aligns with SwiftUI** - Tree structure exists only in views
- **Simple** - No need to manage store hierarchies
- **Clear lifecycle** - Store lifecycle matches view lifecycle
- **Independent testing** - Each feature can be tested in isolation
- **Memory efficient** - Store is deallocated when view disappears

### 3. Result-Returning Actions: Functional Clarity

Actions can return typed results, enabling functional programming patterns and making side effects explicit.

```swift
import SwiftUI
import Flow

struct TodoFeature: Feature {
    @Observable
    final class State {
        var todos: [Todo] = []
    }

    enum Action: Sendable {
        case save(title: String)
    }

    enum ActionResult: Sendable {
        case saved(id: String)
    }

    func handle() -> ActionHandler<Action, State, ActionResult> {
        ActionHandler { action, state in
            switch action {
            case .save(let title):
                return .run { state in
                    let todo = try await api.create(title: title)
                    state.todos.append(todo)
                    return .saved(id: todo.id)
                }
            }
        }
    }
}

// View side
Button("Save") {
    Task {
        let result = await store.send(.save(title: title)).value
        if case .success(.saved(let id)) = result {
            await navigator.navigate(to: .detail(id: id))
        }
    }
}
```

**Benefits:**
- **Actions return values** - Functional clarity like regular functions
- **Parent controls side effects** - Navigation, notifications decided at higher levels
- **Clear responsibility** - Easy to track where things happen
- **Type-safe contract** - Result types are explicit and compile-time checked

**Common use cases:**
- **Form validation** - Return specific validation error types
- **Navigation decisions** - Parent decides where to navigate based on results
- **Error handling** - Different UI responses for different failure types
- **Parent-child communication** - Child returns results, parent handles them

For advanced patterns, see <doc:PracticalGuide#Parent-Child-Communication>.

### 4. MainActor Isolation: Safe State Updates in Async Context ⭐️

One of Flow's most distinctive features: you can **directly update state inside async operations**.

```swift
case .fetchUser:
    state.isLoading = true
    return .run { state in
        // Directly update state inside async context!
        let user = try await api.fetchUser()
        state.user = user
        state.isLoading = false
    }
    .catch { error, state in
        state.isLoading = false
        state.error = error
    }
```

**How it works:**

Flow leverages Swift 6's `defaultIsolation(MainActor.self)` feature, which sets default actor isolation for an entire module. This eliminates the need for explicit `@MainActor` annotations everywhere.

```swift
.defaultIsolation(MainActor.self)
```

All operations run on the MainActor, with **compile-time data race detection**. A data race occurs when multiple threads access the same memory simultaneously and at least one performs a write.

```swift
import Flow

func handle() -> ActionHandler<Action, State, Void> {
    ActionHandler { action, state in
        switch action {
        case .increment:
            state.count += 1  // ✅ Synchronous operations are safe
            return .none

        case .loadData:
            return .run { state in
                let data = try await api.fetch()
                state.data = data  // ✅ State mutations safe even in async
            }
        }
    }
}
```

**Benefits:**
- **Code locality** - Loading, data fetching, and error handling in one place
- **Intuitive** - Write code naturally, just like regular Swift
- **Compile-time safety** - Data races detected at compile time, not runtime
- **No manual dispatch** - No need to manage dispatch queues or MainActor annotations

This approach differs from traditional patterns where you must send new actions or use callbacks to update state from async contexts.

### 5. SwiftUI's Standard Observation

Flow uses SwiftUI's standard **@Observable** macro, introduced in iOS 17, instead of `@ObservableObject` or `@Published`.

```swift
import Observation

@Observable
final class State {
    var count = 0
    var isLoading = false
    var errorMessage: String?
}
```

**Benefits:**
- **No Combine dependency** - Uses SwiftUI's standard features only
- **Optimized by SwiftUI** - Benefits from SwiftUI's diffing and performance improvements
- **Platform aligned** - Grows with Apple's ecosystem evolution
- **Lower learning curve** - Natural for SwiftUI developers
- **Less boilerplate** - No need for `@Published` annotations

## Additional Features

### Middleware for Cross-Cutting Concerns

While not a core principle, Flow provides middleware for observing actions across your application. This is useful for logging, analytics, and debugging:

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

For detailed information, see <doc:Middleware>.

## Next Steps

Now that you understand Flow's core principles, let's explore the implementation details:

- **Next**: <doc:CoreElements>

**Recommended learning path**:
1. <doc:CoreElements> - Learn about Feature, Store, ActionHandler, and ActionTask
2. <doc:Middleware> - Add cross-cutting concerns like logging and analytics
3. <doc:PracticalGuide> - See practical patterns and real-world examples

## See Also

- ``Store``
- ``Feature``
- ``ActionHandler``
- ``ActionTask``
