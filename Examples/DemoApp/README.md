# Flow Demo App

A comprehensive iOS demonstration app showcasing the Flow library's capabilities for building modern SwiftUI applications with unidirectional data flow architecture.

## Overview

This demo app demonstrates how to use Flow to build robust, maintainable iOS applications using the Store pattern with clean separation of concerns.

## Features

### 1. Counter Demo
A simple counter application demonstrating:
- Basic state management with `Store` and `StoreFeature`
- Synchronous actions (increment, decrement, reset)
- Asynchronous actions with loading states (delayed increment)
- Modern SwiftUI animations and transitions

**Key Concepts:**
- State mutation through actions
- Task management with `.run`
- Loading state handling

### 2. Todo List Demo
A full-featured todo list application showing:
- CRUD operations (Create, Read, Update, Delete)
- List management with SwiftUI
- Empty state handling with `ContentUnavailableView`
- State-driven UI updates

**Key Concepts:**
- Complex state management
- Array manipulation in state
- Form input handling
- Deletion with gestures

### 3. User Management Demo
An advanced user management interface featuring:
- User listing with role-based badges
- Search functionality
- Modal editing with forms
- Async data loading simulation
- Complex navigation patterns

**Key Concepts:**
- Navigation with sheets
- Search integration
- Picker components
- Loading states for network simulation
- Form validation

## Requirements

- iOS 18.0+
- Swift 6.2+

## Getting Started

### Open in Xcode

1. Navigate to the `Examples/DemoApp` directory
2. Open `DemoApp.xcodeproj` in Xcode
3. Select a simulator or device
4. Build and run (⌘R)

The app will automatically load the Flow library from the parent directory using Swift Package Manager local package reference.

### Project Structure

```
DemoApp/
├── DemoApp.xcodeproj/          # Xcode project file
├── DemoApp/
│   ├── DemoApp.swift           # App entry point
│   ├── ContentView.swift       # Main navigation view
│   ├── Features/
│   │   ├── Counter/
│   │   │   ├── CounterFeature.swift   # Counter business logic
│   │   │   └── CounterView.swift      # Counter UI
│   │   ├── TodoList/
│   │   │   ├── TodoFeature.swift      # Todo business logic
│   │   │   └── TodoView.swift         # Todo UI
│   │   └── UserManagement/
│   │       ├── UserFeature.swift      # User management logic
│   │       └── UserView.swift         # User management UI
│   └── Assets.xcassets/        # App assets
└── README.md                   # This file
```

## Learning Path

We recommend exploring the demos in this order:

1. **Counter Demo** - Learn the basics of Store, State, and Actions
2. **Todo List Demo** - Understand CRUD operations and list management
3. **User Management Demo** - Master advanced patterns like navigation and async operations

## Code Examples

### Creating a Feature

```swift
// Define your feature with nested State and Action
struct CounterFeature: StoreFeature {
    // 1. Define your state (nested @Observable class)
    @Observable
    final class State: Sendable {
        var count = 0

        init(count: Int = 0) {
            self.count = count
        }
    }

    // 2. Define your actions (nested enum)
    enum Action: Sendable {
        case increment
        case decrement
        case asyncIncrement
    }

    // 3. Create your action handler
    func handle() -> ActionHandler<Action, State> {
        ActionHandler { action, state in
            switch action {
            case .increment:
                state.count += 1
                return .none

            case .decrement:
                state.count -= 1
                return .none

            case .asyncIncrement:
                return .run(id: "increment") {
                    try await Task.sleep(for: .seconds(1))
                    // Dispatch further actions if needed
                }
            }
        }
    }
}
```

### Using a Store in SwiftUI

```swift
// Use the store in your view
struct CounterView: View {
    @State private var store = Store(
        initialState: CounterFeature.State(),
        feature: CounterFeature()
    )

    var body: some View {
        VStack {
            Text("Count: \(store.state.count)")
                .font(.largeTitle)

            HStack {
                Button("−") {
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

## Key Patterns Demonstrated

### State Management
- Immutable state updates through actions
- Observable pattern with `@Observable` macro
- Type-safe state access in views

### Action Handling
- Synchronous actions for immediate state changes
- Asynchronous actions with `.run` for side effects
- Task management with identifiers
- Error handling patterns

### SwiftUI Integration
- `@State` property wrapper for store instances
- Reactive UI updates
- Navigation patterns (sheets, push navigation)
- Form handling and validation

## Testing

Each feature in this demo can be easily tested using Flow's `TestStore`:

```swift
func testCounter() async {
    let store = TestStore(
        initialState: CounterFeature.State(),
        feature: CounterFeature()
    )

    await store.send(.increment) { state in
        state.count = 1
    }
}
```

## Additional Resources

- [Flow Documentation](../../../README.md)
- [API Reference](../../../Sources/Flow/)
- [Test Examples](../../../Tests/)

## License

This demo app is part of the Flow library and is available under the same license terms.
