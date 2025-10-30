# Core Elements

Learn about the five core types that make up Flow.

## Overview

Flow consists of five core elements:

- **Store** - State management and action coordination
- **Feature** - State, actions, and business logic definition
- **ActionHandler** - Action processing and task return
- **ActionResult** - Action processing result type
- **ActionTask** - Async processing and task management

These elements work together to build applications.

## Store

**Store** manages state, receives actions from views, sends them to handlers, and processes results.

```swift
import SwiftUI
import Flow

@State private var store = Store(
    initialState: MyState(),
    feature: MyFeature()
)

var body: some View {
    VStack {
        Text("\(store.state.count)")
        Button("Increment") {
            store.send(.increment)
        }
    }
}
```

## Feature

**Feature** defines State, Action, and ActionHandler in one place.

```swift
import Flow

struct UserFeature: Feature {
    @Observable
    final class State {
        var user: User?
        var isLoading = false
    }

    enum Action: Sendable {
        case load
        case logout
    }

    func handle() -> ActionHandler<Action, State, Void> {
        ActionHandler { action, state in
            // Business logic goes here
        }
    }
}
```

## ActionHandler

**ActionHandler** receives actions and current state, updates state, and returns an ActionTask.

```swift
ActionHandler<Action, State, ActionResult>
```

Type parameters:
- **Action** - Action type to process
- **State** - Feature's state type
- **ActionResult** - Action processing result type

## ActionResult

**ActionResult** represents the result of action processing. Views receive this result to make decisions like navigation or showing toasts.

### Returning Results

**Return results from synchronous processing:**

Use `.just()` to return results immediately.

```swift
ActionHandler { action, state in
    switch action {
    case .save(let item):
        let id = UUID().uuidString
        state.items.append(item.with(id: id))
        return .just(.created(id: id))  // Return result synchronously
    }
}
```

**Return results from async processing:**

Perform processing in a `.run` block and return the result.

```swift
ActionHandler { action, state in
    switch action {
    case .load:
        return .run { state in
            let user = try await api.fetchUser()
            state.user = user
            return .loaded(userId: user.id)  // Return result after async processing
        }
    }
}
```

**When no result is needed:**

Return `.none` when the result type is `Void`. `.none` is optional.

```swift
ActionHandler { action, state in
    switch action {
    case .increment:
        state.count += 1
        return .none  // Optional
    }
}
```

### Receiving Results in Views

Example of receiving and processing results:

```swift
Task {
    let result = await store.send(.save(item)).value
    switch result {
    case .success(.created(let id)):
        print("Created: \(id)")
        // Navigate or show toast
    case .success(.updated):
        print("Updated")
    case .success(.noChange):
        print("No change")
    case .failure(let error):
        print("Error: \(error)")
    }
}
```

### When to Use

- **Void** - When no result is needed (state updates only)
- **Custom type** - When the caller needs to handle the result
  - Distinguish create/update/delete success patterns
  - Validation results
  - Navigation decisions

## ActionTask

**ActionTask** manages async processing execution and task cancellation.

Execution results are returned to views as ActionResult.

```swift
ActionTask<Action, State, ActionResult>
```

### Task Types

**Task returning Void immediately**

```swift
return .none
```

**Task returning result immediately**

```swift
return .just(.success)
```

**Execute async processing**

```swift
return .run { state in
    let user = try await api.fetchUser()
    state.user = user
}
.cancellable(id: "load-user", cancelInFlight: true)
```

**Cancel running task**

```swift
// When returning Void (ActionResult == Void)
return .cancel(id: "load-user")

// When returning custom result
enum SaveResult: Sendable {
    case cancelled
    case saved(id: String)
}

return .cancel(id: "save", returning: .cancelled)
```

**Task executing multiple tasks sequentially**

Static tasks (compile-time):

```swift
// Execute multiple steps in sequence
return .concatenate(
    .run { state in
        state.step = 1
        try await Task.sleep(for: .seconds(1))
    },
    .run { state in
        state.step = 2
        try await Task.sleep(for: .seconds(1))
    },
    .run { state in
        state.step = 3
    }
)
```

Dynamic tasks (runtime) - guard against empty:

```swift
// Process items dynamically
let tasks = items.map { item in
    ActionTask.run { state in
        try await process(item)
    }
}

// Empty arrays require explicit handling
guard !tasks.isEmpty else {
    return .none  // Or handle empty case appropriately
}

return try .concatenate(tasks)
```

Each task executes after the previous one completes. The final task's result is returned to the view.

## Next Steps

Now that you understand the core elements, let's learn practical usage:

- **Next**: <doc:Middleware>

## See Also

- ``Store``
- ``Feature``
- ``ActionHandler``
- ``ActionTask``
