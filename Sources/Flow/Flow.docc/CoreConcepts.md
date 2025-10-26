# Core Concepts

Learn how unidirectional data flow and core components work.

## Overview

This guide explains Flow's design philosophy and key features. You'll learn about unidirectional data flow, why Flow avoids global stores, result-returning actions, and other important concepts.

## Unidirectional Data Flow

Flow adopts unidirectional data flow. All state changes occur through actions, making it easy to track how state evolves.

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

- State scope is clear (same lifecycle as the view)
- No need to manage global state

### Result-Returning Actions

Actions can return results through `ActionTask`. The result type (`ActionResult`) can be freely defined for each Feature.

In this example, a child view returns a selection result to the parent, which handles navigation:

```swift
import SwiftUI
import Flow

struct ParentView: View {
    @Environment(\.navigator) private var navigator

    var body: some View {
        ChildView { selectedId in
            await navigator.navigate(to: .detail(id: selectedId))
        }
    }
}

struct ChildView: View {
    @State private var store = Store(
        initialState: .init(),
        feature: ChildFeature()
    )
    let onSelect: (String) async -> Void

    var body: some View {
        Button("Select") {
            Task {
                let result = await store.send(.select).value
                if case .success(.selected(let id)) = result {
                    await onSelect(id)
                }
            }
        }
    }
}

struct ChildFeature: Feature {
    @Observable
    final class State {
        var selectedId = ""
    }

    enum Action: Sendable {
        case select
    }

    enum ActionResult: Sendable {
        case selected(id: String)
    }

    func handle() -> ActionHandler<Action, State, ActionResult> {
        ActionHandler { action, state in
            switch action {
            case .select:
                return .run { state in
                    let id = state.selectedId
                    return .selected(id: id)
                }
            }
        }
    }
}
```

This implementation provides:
- `ChildFeature` returns selection results to the parent via `ActionResult`
- `ParentView` receives results through the `onSelect` callback
- Parent controls side effects like navigation
- Everything stays within the view tree, making dependencies easy to track

See <doc:PracticalGuide> for more details.

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

### Approachable Concurrency

Supports **Approachable Concurrency**.

A Swift 6 feature that allows setting default actor isolation for an entire module. Flow assumes `defaultIsolation(MainActor.self)`, eliminating the need for explicit `@MainActor` annotations.

```swift
.defaultIsolation(MainActor.self)
```

This ensures all operations run on the MainActor, with **data races caught at compile time**. A data race occurs when multiple threads access the same memory simultaneously and at least one performs a write.

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

- Thread-safety guaranteed
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

- Observe all actions in one place
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
