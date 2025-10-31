# ``Flow``

A library for managing state in SwiftUI applications in a type-safe way. Flow provides a unidirectional data flow architecture and supports Observation and Swift 6 Approachable Concurrency.

## Overview

Flow brings predictable state management to SwiftUI with a view-local approach. Unlike architectures with global stores (Redux, TCA), Flow keeps state scoped to views, making it easier to reason about lifecycle and dependencies.

**Design Philosophy:**
- **View-local state** - No singleton stores to manage
- **Unidirectional flow** - Actions → Handler → State → View
- **Type-safe results** - Actions can return typed results for navigation and error handling
- **Concurrency-first** - Built for Swift 6 with MainActor isolation

**Quick Example:**

```swift
import SwiftUI
import Flow

// Define your feature
struct CounterFeature: Feature {
    @Observable final class State {
        var count = 0
    }

    enum Action: Sendable {
        case increment
    }

    func handle() -> ActionHandler<Action, State, Void> {
        ActionHandler { action, state in
            state.count += 1
            return .none
        }
    }
}

// Use in your view
struct CounterView: View {
    @State private var store = Store(
        initialState: .init(),
        feature: CounterFeature()
    )

    var body: some View {
        Button("Count: \(store.state.count)") {
            store.send(.increment)
        }
    }
}
```

For a complete walkthrough, see <doc:GettingStarted>.

**Architecture:**

![Flow Architecture](flow-diagram.svg)

Actions flow through the handler, update state, and SwiftUI re-renders automatically.

## Key Features

- **No global store** - Each view holds its own state with `@State`
- **Result-returning actions** - Views receive action processing results
- **Swift 6 support** - Thread-safe by default with Approachable Concurrency
- **@Observable support** - Uses SwiftUI's standard `@Observable` with no Combine dependency
- **Flexible middleware** - Add cross-cutting concerns like logging, analytics, and debugging

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:CoreConcepts>
- <doc:CoreElements>
- <doc:Middleware>

### Practical Guide

- <doc:PracticalGuide>
