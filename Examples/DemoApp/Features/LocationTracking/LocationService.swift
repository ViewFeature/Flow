import CoreLocation
import Foundation
import Observation

/// CoreLocationManager wrapper that provides async/await API
@MainActor
final class LocationService: NSObject {
  private let manager = CLLocationManager()
  private var continuation: AsyncStream<Result<CLLocation, Error>>.Continuation?

  nonisolated override init() {
    super.init()
    Task { @MainActor in
      self.manager.delegate = self
      self.manager.desiredAccuracy = kCLLocationAccuracyBest
      self.manager.distanceFilter = 10  // Update every 10 meters
    }
  }

  /// Request location authorization
  func requestAuthorization() {
    manager.requestWhenInUseAuthorization()
  }

  /// Get current authorization status
  var authorizationStatus: CLAuthorizationStatus {
    manager.authorizationStatus
  }

  /// Start location updates stream
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

  /// Stop location updates
  func stopLocationUpdates() {
    manager.stopUpdatingLocation()
    continuation?.finish()
    continuation = nil
  }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
  nonisolated func locationManager(
    _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
  ) {
    guard let location = locations.last else { return }
    Task { @MainActor in
      continuation?.yield(.success(location))
    }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    Task { @MainActor in
      continuation?.yield(.failure(error))
    }
  }

  nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    // Authorization changes are handled through actions
  }
}
