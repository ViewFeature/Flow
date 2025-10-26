import CoreLocation
import Flow
import Foundation
import Observation

struct LocationFeature: Feature {
  // MARK: - Dependencies

  let locationService: LocationService

  // MARK: - State

  @Observable
  final class State {
    var currentLocation: CLLocation?
    var locationHistory: [CLLocation] = []
    var isTracking: Bool = false
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var errorMessage: String?

    /// Maximum number of locations to keep in history
    let maxHistoryCount = 100

    init(
      currentLocation: CLLocation? = nil,
      locationHistory: [CLLocation] = [],
      isTracking: Bool = false,
      authorizationStatus: CLAuthorizationStatus = .notDetermined,
      errorMessage: String? = nil
    ) {
      self.currentLocation = currentLocation
      self.locationHistory = locationHistory
      self.isTracking = isTracking
      self.authorizationStatus = authorizationStatus
      self.errorMessage = errorMessage
    }
  }

  // MARK: - Action

  enum Action: Sendable {
    case requestAuthorization
    case startTracking
    case stopTracking
    case locationUpdated(CLLocation)
    case locationError(Error)
    case updateAuthorizationStatus
    case clearHistory
  }

  // MARK: - Handler

  func handle() -> ActionHandler<Action, State, Void> {
    ActionHandler { [locationService] action, state in
      switch action {
      case .requestAuthorization:
        locationService.requestAuthorization()
        state.authorizationStatus = locationService.authorizationStatus
        return .none

      case .startTracking:
        state.isTracking = true
        state.errorMessage = nil

        return .run { state in
          let stream = locationService.startLocationUpdates()
          for await result in stream {
            switch result {
            case .success(let location):
              state.currentLocation = location
              state.locationHistory.append(location)

              // Keep only recent locations
              if state.locationHistory.count > state.maxHistoryCount {
                state.locationHistory.removeFirst()
              }

            case .failure(let error):
              state.errorMessage = error.localizedDescription
            }
          }
        }
        .cancellable(id: "location-tracking")
        .catch { error, state in
          state.isTracking = false
          state.errorMessage = error.localizedDescription
        }

      case .stopTracking:
        state.isTracking = false
        locationService.stopLocationUpdates()
        return .cancel(id: "location-tracking")

      case .locationUpdated(let location):
        state.currentLocation = location
        state.locationHistory.append(location)

        // Keep only recent locations
        if state.locationHistory.count > state.maxHistoryCount {
          state.locationHistory.removeFirst()
        }
        return .none

      case .locationError(let error):
        state.errorMessage = error.localizedDescription
        return .none

      case .updateAuthorizationStatus:
        state.authorizationStatus = locationService.authorizationStatus
        return .none

      case .clearHistory:
        state.locationHistory.removeAll()
        state.currentLocation = nil
        return .none
      }
    }
  }
}
