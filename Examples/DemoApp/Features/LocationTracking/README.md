# Location Tracking Example

A real-world example demonstrating how to use Flow with CoreLocation and MapKit for continuous location tracking and visualization.

## Features

- ✅ Real-time location tracking with CoreLocation
- ✅ MapKit integration with SwiftUI
- ✅ Location history with path visualization
- ✅ Authorization handling
- ✅ Error handling with user feedback
- ✅ Automatic cleanup when view disappears

## Architecture

This example demonstrates Flow's ability to handle:

1. **Async Streams** - CoreLocation updates via AsyncStream
2. **Long-running Tasks** - Continuous location tracking
3. **Automatic Cancellation** - Tasks are cancelled when tracking stops or view disappears
4. **State Management** - Location history, tracking state, authorization status
5. **Error Handling** - Graceful error recovery with user feedback

## Components

### LocationService

A `@MainActor` wrapper around `CLLocationManager` that provides an async/await API:

```swift
let stream = locationService.startLocationUpdates()
for await result in stream {
    // Handle location updates
}
```

### LocationFeature

Feature-based state management for location tracking:

```swift
struct LocationFeature: Feature {
    @Observable
    final class State {
        var currentLocation: CLLocation?
        var locationHistory: [CLLocation] = []
        var isTracking: Bool = false
        var authorizationStatus: CLAuthorizationStatus
        var errorMessage: String?
    }

    enum Action: Sendable {
        case startTracking
        case stopTracking
        case locationUpdated(CLLocation)
        case locationError(Error)
        // ...
    }
}
```

### LocationTrackingView

SwiftUI view with MapKit integration:

- Real-time map updates
- Location history visualization with polyline
- Status card with current coordinates
- Start/Stop tracking controls

## Key Patterns

### 1. Task Cancellation

```swift
case .startTracking:
    return .run { state in
        let stream = locationService.startLocationUpdates()
        for await result in stream {
            // Process location updates
        }
    }
    .cancellable(id: "location-tracking")

case .stopTracking:
    return .cancel(id: "location-tracking")
```

### 2. AsyncStream Integration

```swift
func startLocationUpdates() -> AsyncStream<Result<CLLocation, Error>> {
    AsyncStream { continuation in
        self.continuation = continuation
        self.manager.startUpdatingLocation()

        continuation.onTermination = { @Sendable _ in
            Task { @MainActor in
                self.manager.stopUpdatingLocation()
            }
        }
    }
}
```

### 3. Error Handling

```swift
.catch { error, state in
    state.isTracking = false
    state.errorMessage = error.localizedDescription
}
```

### 4. Automatic Cleanup

When the view disappears, the Store is deallocated and all running tasks are automatically cancelled. No manual cleanup needed!

## Requirements

- iOS 18.0+
- Location permissions configured in Info.plist:
  - `NSLocationWhenInUseUsageDescription`
  - `NSLocationAlwaysAndWhenInUseUsageDescription`

## Usage

1. Request location authorization
2. Tap "Start Tracking" to begin tracking
3. Watch the map update in real-time
4. The blue line shows your path
5. Tap "Stop Tracking" to stop
6. Use the trash icon to clear history

## Testing

This example works best when:

- Testing on a real device (not simulator)
- Moving around outdoors for GPS accuracy
- Granting "While Using App" permission

For simulator testing:

1. Simulator → Features → Location
2. Choose "City Run" or "Freeway Drive"

## What This Demonstrates

✅ **MainActor Isolation** - All location updates happen on MainActor
✅ **Structured Concurrency** - AsyncStream properly manages task lifecycle
✅ **Automatic Cleanup** - No memory leaks or orphaned tasks
✅ **Clean Architecture** - Separation of concerns (Service, Feature, View)
✅ **Real-world Integration** - CoreLocation + MapKit with Flow

## Learning Points

1. **AsyncStream** is perfect for delegate-based APIs like CoreLocation
2. **Cancellable tasks** ensure proper cleanup
3. **MainActor** simplifies UI updates
4. **Flow** handles the complexity, you write clean code

---

**Try it out**: Run the DemoApp and select "Location Tracking" from the menu!
