# Getting Started

Learn how to integrate Flow by building a counter feature.

## Overview

Build a counter with state management and action handling.

## Requirements

- iOS 18.0+ / macOS 15.0+ / watchOS 11.0+ / tvOS 18.0+
- Swift 6.2+

## Installation

### Swift Package Manager

Add Flow to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ViewFeature/Flow.git", from: "0.1.6")
]
```

**Recommended**: Enable default MainActor isolation for your app:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "Flow", package: "Flow")
    ],
    swiftSettings: [
        .defaultIsolation(MainActor.self)  // Recommended
    ]
)
```

### Xcode

1. Select **File → Add Package Dependencies**
2. Enter the URL: `https://github.com/ViewFeature/Flow.git`
3. Select version: `0.1.6` or later
4. Add to your target's **Build Settings → Other Swift Flags**: `-default-isolation MainActor`

## Build a Counter App

### Step 1

Create a Feature and define State, Action, and Handler.

```swift
import Flow

struct CounterFeature: Feature {
    @Observable
    final class State {
        var count = 0
    }

    enum Action: Sendable {
        case increment
        case decrement
        case reset
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

            case .reset:
                state.count = 0
                return .none
            }
        }
    }
}
```

### Step 2

Create a View and integrate the Store.

```swift
import SwiftUI
import Flow

struct CounterView: View {
    @State private var store = Store(
        initialState: .init(),
        feature: CounterFeature()
    )

    var body: some View {
        VStack(spacing: 20) {
            Text("\(store.state.count)")
                .font(.largeTitle)

            HStack {
                Button("−") {
                    store.send(.decrement)
                }
                Button("Reset") {
                    store.send(.reset)
                }
                Button("+") {
                    store.send(.increment)
                }
            }
        }
    }
}
```

That's it! You've implemented the basic functionality.

## Next Steps

Now that you've built a counter app, let's dive deeper into Flow's architecture:

- **Next**: <doc:CoreConcepts>

**Recommended learning path**:
1. <doc:CoreElements>
2. <doc:Middleware>
3. <doc:PracticalGuide>

## See Also

- ``Store``
- ``Feature``
- ``ActionHandler``
- ``ActionTask``
