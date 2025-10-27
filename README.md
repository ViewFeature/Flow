# Flow

[![Swift 6.2+](https://img.shields.io/badge/Swift-6.2+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20|%20macOS%20|%20watchOS%20|%20tvOS-blue.svg)](https://github.com/ViewFeature/Flow)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

[日本語版](README_jp.md)

A type-safe state management library for SwiftUI applications. Flow provides a unidirectional data flow architecture with full support for Swift 6 Approachable Concurrency.

<p align="center">
    <img src="flow-diagram.svg" alt="Flow Architecture Diagram" />
</p>

### Counter App Example

```swift
import Flow
import SwiftUI

struct CounterFeature: Feature {
    @Observable
    final class State {
        var count = 0
    }

    enum Action: Sendable {
        case increment
        case decrement
    }

    func handle() -> ActionHandler<Action, State, Void> {
        ActionHandler { action, state in
            switch action {
            case .increment:
                state.count += 1
                return .none

            case .decrement:
                state.count -= 1
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

            HStack(spacing: 16) {
                Button("-") {
                    store.send(.decrement)
                }

                Button("+") {
                    store.send(.increment)
                }
            }
        }
    }
}
```

## Key Features

### No Global Store

Each view holds its own state with `@State`.

```swift
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
struct ChildSelectFeature: Feature {
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

struct ChildView: View {
    @State private var store = Store(
        initialState: .init(),
        feature: ChildSelectFeature()
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

struct ParentView: View {
    @Environment(\.navigator) private var navigator

    var body: some View {
        ChildView { selectedId in
            await navigator.navigate(to: .detail(id: selectedId))
        }
    }
}
```

This implementation provides:
- `ChildFeature` returns selection results to the parent via `ActionResult`
- `ParentView` receives results through the `onSelect` callback
- Parent controls side effects like navigation
- Everything stays within the view tree, making dependencies easy to track

### @Observable Support

Uses SwiftUI's standard **@Observable** instead of `@ObservableObject` or `@Published`.

```swift
@Observable
final class State {
    var count = 0  // No @Published needed
}
```

- No Combine dependency
- Less boilerplate code
- Integrates with SwiftUI's standard APIs

### Approachable Concurrency

Supports Swift 6 concurrency checking. Designed with `defaultIsolation(MainActor.self)` in mind.

```swift
.defaultIsolation(MainActor.self)
```

All operations run on the MainActor, with **data races caught at compile time**.

```swift
func handle() -> ActionHandler<Action, State, Void> {
    ActionHandler { action, state in
        switch action {
        case .increment:
            state.count += 1  // ✅ Synchronous operations are safe
            return .none

        case .loadData:
            return .run { state in
                let data = try await api.fetch()
                state.data = data  // ✅ State mutations safe even in async operations
            }
        }
    }
}
```

- Thread-safety guaranteed
- Native `async/await` support
- Direct state mutations in `.run` blocks

### Observable Actions

Flow uses **middleware** to observe actions, enabling cross-cutting concerns like logging, analytics, and debugging.

```swift
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
- Logging, analytics, and debugging support

## Documentation

📖 **[Full Documentation](https://viewfeature.github.io/Flow/)**

- **[Getting Started](https://viewfeature.github.io/Flow/documentation/flow/gettingstarted/)**
- **[Core Concepts](https://viewfeature.github.io/Flow/documentation/flow/coreconcepts/)**
- **[Core Elements](https://viewfeature.github.io/Flow/documentation/flow/coreelements/)**
- **[Practical Guide](https://viewfeature.github.io/Flow/documentation/flow/practicalguide/)**
- **[Middleware](https://viewfeature.github.io/Flow/documentation/flow/middleware/)**

## Installation

### Swift Package Manager

Add Flow to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ViewFeature/Flow.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "Flow", package: "Flow")
        ],
        swiftSettings: [
            .defaultIsolation(MainActor.self)  // Recommended
        ]
    )
]
```

### Xcode

- Select **File → Add Package Dependencies**
- Enter the URL: `https://github.com/ViewFeature/Flow.git`
- Select version: `1.0.0` or later

**Recommended**: Add `-default-isolation MainActor` to your target's **Build Settings → Other Swift Flags**.

### Requirements

- iOS 18.0+ / macOS 15.0+ / watchOS 11.0+ / tvOS 18.0+
- Swift 6.2+
- Xcode 16.2+

## Contributing

Contributions are welcome!

Before submitting a pull request, please review the [Contributing Guide](CONTRIBUTING.md). If you have questions or ideas, start a [Discussion](https://github.com/ViewFeature/Flow/discussions).

### Community

- 🐛 **[Report Issues](https://github.com/ViewFeature/Flow/issues)** - Bug reports and feature requests
- 💬 **[Discussions](https://github.com/ViewFeature/Flow/discussions)** - Share questions and ideas

## Credits

Flow is inspired by the following libraries and communities:

- [Redux](https://redux.js.org/) - Unidirectional data flow architecture
- [ReSwift](https://github.com/ReSwift/ReSwift) - Unidirectional data flow in Swift
- [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) - State management patterns in Swift

## Maintainers

- [Takeshi SHIMADA](https://github.com/takeshishimada)

## License

Flow is distributed under the MIT License. See the [LICENSE](LICENSE) file for details.
