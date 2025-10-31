# Flow

[![Swift 6.2+](https://img.shields.io/badge/Swift-6.2+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20|%20macOS%20|%20watchOS%20|%20tvOS-blue.svg)](https://github.com/ViewFeature/Flow)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

[日本語版](README_jp.md)

A type-safe state management library for SwiftUI applications. Flow provides a unidirectional data flow architecture and supports Observation and Swift 6 Concurrency.

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

## The 5 Core Principles

### 1. Unidirectional Data Flow

All state changes flow in one direction: **Action → Handler → State → View**. This makes your app's behavior predictable and easy to debug.

```swift
Button("Load") {
    store.send(.load)  // Action flows to handler
}

// Handler updates state
case .load:
    return .run { state in
        state.data = try await api.fetch()  // State flows to view
    }
```

- Predictable data flow
- Easy to trace state changes
- Well-defined inputs and outputs

### 2. View-Local State

Each view holds its own state with `@State`, aligned with SwiftUI's philosophy. No global store, no store hierarchies.

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

- Clear lifecycle (store lives with view)
- No global state management
- Memory efficient

### 3. Result-Returning Actions

Actions return typed results, enabling functional patterns and making side effects explicit.

```swift
enum ActionResult: Sendable {
    case saved(id: String)
}

// In handler
case .save(let title):
    return .run { state in
        let todo = try await api.create(title: title)
        return .saved(id: todo.id)  // Return result
    }

// In view
Button("Save") {
    Task {
        let result = await store.send(.save(title: title)).value
        if case .success(.saved(let id)) = result {
            await navigator.navigate(to: .detail(id: id))
        }
    }
}
```

- Actions return values like functions
- Parent controls navigation and side effects
- Type-safe contracts

### 4. MainActor Isolation

Directly update state inside async operations—safely. Flow leverages Swift 6's `defaultIsolation(MainActor.self)` for compile-time safety.

```swift
case .fetchUser:
    state.isLoading = true
    return .run { state in
        // Directly update state in async context!
        let user = try await api.fetchUser()
        state.user = user
        state.isLoading = false
    }
```

- Code locality (loading, fetching, errors in one place)
- Intuitive (write naturally like regular Swift)
- Compile-time safety (data races caught at compile time)

### 5. @Observable Support

Uses SwiftUI's standard **@Observable** instead of `@ObservableObject` or `@Published`.

```swift
@Observable
final class State {
    var count = 0  // No @Published needed
}
```

- No Combine dependency
- Less boilerplate
- Platform aligned with SwiftUI

## Documentation

📖 **[Full Documentation](https://viewfeature.github.io/Flow/documentation/flow/)**

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
    .package(url: "https://github.com/ViewFeature/Flow.git", from: "1.3.1")
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
- Select version: `1.3.1` or later

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
