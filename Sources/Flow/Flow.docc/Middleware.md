# Middleware

Learn how to implement middleware.

## Overview

Middleware provides hooks into the action processing pipeline. Add logging, analytics, validation, and custom behavior without modifying features.

| Timing | Description |
|--------|-------------|
| `beforeAction` | Before the handler processes the action |
| `afterAction` | After the handler completes |
| `onError` | When an error occurs during processing |

## Creating Custom Middleware

### Immutable Middleware

Use structs for stateless middleware:

```swift
import Flow

struct AnalyticsMiddleware: ActionMiddleware {
    let id = "Analytics"
    let analytics: AnalyticsService

    func beforeAction<Action, State>(_ action: Action, state: State) async {
        analytics.trackActionStarted(String(describing: action))
    }

    func afterAction<Action, State, ActionResult>(
        _ action: Action,
        state: State,
        result: ActionTask<Action, State, ActionResult>
    ) async where ActionResult: Sendable {
        // ActionResult can be any type (Void, custom types, etc.)
        analytics.trackActionCompleted(String(describing: action))
    }

    func onError<Action, State>(_ error: Error, action: Action, state: State) async {
        analytics.trackError(
            error: error,
            action: String(describing: action),
            context: ["state": String(describing: state)]
        )
    }
}
```

### Stateful Middleware

Use `final class` with `@unchecked Sendable` when middleware needs to track state:

> Warning: `@unchecked Sendable` bypasses Swift's thread-safety checks. You must ensure thread-safety manually. This is safe in Flow because all middleware operations run on the MainActor.

```swift
import Flow

final class TimingMiddleware: ActionMiddleware, @unchecked Sendable {
    // ⚠️ @unchecked Sendable: We guarantee thread-safety because Flow ensures
    // all middleware methods execute on MainActor with defaultIsolation
    let id = "TimingMiddleware"
    private var startTimes: [String: Date] = [:]

    func beforeAction<Action, State>(_ action: Action, state: State) async {
        let key = String(describing: action)
        startTimes[key] = Date()
        print("⏱️ Started: \(action)")
    }

    func afterAction<Action, State, ActionResult>(
        _ action: Action,
        state: State,
        result: ActionTask<Action, State, ActionResult>
    ) async where ActionResult: Sendable {
        let key = String(describing: action)
        if let startTime = startTimes[key] {
            let duration = Date().timeIntervalSince(startTime)
            print("✅ Completed: \(action) in \(duration)s")
            startTimes.removeValue(forKey: key)
        }
    }

    func onError<Action, State>(_ error: Error, action: Action, state: State) async {
        let key = String(describing: action)
        if let startTime = startTimes[key] {
            let duration = Date().timeIntervalSince(startTime)
            print("❌ Failed: \(action) in \(duration)s - \(error)")
            startTimes.removeValue(forKey: key)
        }
    }
}
```

## Built-in Middleware

### LoggingMiddleware

Flow includes a built-in logging middleware for debugging:

```swift
import Flow

func handle() -> ActionHandler<Action, State, Void> {
    ActionHandler { action, state in
        // Action processing logic
    }
    .use(LoggingMiddleware(category: "MyFeature"))
}
```

**Output:**
```
[MyFeature] ▶ Action: increment
[MyFeature] ◀ Completed: increment (0.002s)
```

**On error:**
```
[MyFeature] ▶ Action: loadData
[MyFeature] ✗ Error: Network error (0.145s)
```

## Using Multiple Middleware

Chain multiple middleware with `.use()` to compose cross-cutting concerns.

**Example:**

```swift
import Flow

func handle() -> ActionHandler<Action, State, Void> {
    ActionHandler { action, state in
        // Action processing logic
    }
    .use(LoggingMiddleware(category: "UserFeature"))
    .use(AnalyticsMiddleware(analytics: .shared))
    .use(ErrorReportingMiddleware(reporter: .production))
}
```

**Execution order:**

Middleware executes in the order they are added:

1. **beforeAction** - Top to bottom (Logging → Analytics → Error Reporting)
2. **Action processing** - Your handler executes
3. **afterAction** - Bottom to top (Error Reporting → Analytics → Logging)
4. **onError** - Top to bottom (Logging → Analytics → Error Reporting)

This order ensures that:
- Logging middleware sees all actions first
- Error reporting catches all failures
- Analytics tracks after processing completes

## Next Steps

Now that you can add cross-cutting concerns with middleware, let's learn practical patterns:

- **Next**: <doc:PracticalGuide>

## See Also

- <doc:PracticalGuide>
- ``ActionMiddleware``
- ``LoggingMiddleware``
- ``BeforeActionMiddleware``
- ``AfterActionMiddleware``
- ``ErrorHandlingMiddleware``
