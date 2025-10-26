import CoreLocation
import Flow
import MapKit
import SwiftUI

struct LocationTrackingView: View {
  @State private var store: Store<LocationFeature>

  init() {
    let locationService = LocationService()
    let feature = LocationFeature(locationService: locationService)
    self._store = State(
      initialValue: Store(
        initialState: LocationFeature.State(),
        feature: feature
      ))
  }

  @State private var cameraPosition: MapCameraPosition = .automatic

  var body: some View {
    ZStack(alignment: .bottom) {
      // Map with location tracking
      Map(position: $cameraPosition) {
        // Current location marker
        if let currentLocation = store.state.currentLocation {
          Annotation("Current Location", coordinate: currentLocation.coordinate) {
            ZStack {
              Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 20, height: 20)
              Circle()
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 20, height: 20)
            }
          }
        }

        // Location history path
        if store.state.locationHistory.count >= 2 {
          MapPolyline(coordinates: store.state.locationHistory.map(\.coordinate))
            .stroke(Color.blue, lineWidth: 3)
        }
      }
      .mapStyle(.standard(elevation: .realistic))
      .mapControls {
        MapUserLocationButton()
        MapCompass()
        MapScaleView()
      }

      // Controls overlay
      VStack {
        // Status card
        StatusCard(
          isTracking: store.state.isTracking,
          locationCount: store.state.locationHistory.count,
          currentLocation: store.state.currentLocation,
          errorMessage: store.state.errorMessage
        )
        .padding()

        // Control buttons
        HStack(spacing: 16) {
          if !store.state.isTracking {
            Button {
              store.send(.startTracking)
            } label: {
              Label("Start Tracking", systemImage: "location.fill")
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(
              store.state.authorizationStatus != .authorizedWhenInUse
                && store.state.authorizationStatus != .authorizedAlways)
          } else {
            Button {
              store.send(.stopTracking)
            } label: {
              Label("Stop Tracking", systemImage: "stop.fill")
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
          }

          Button {
            store.send(.clearHistory)
          } label: {
            Image(systemName: "trash")
              .padding()
              .background(Color.secondary.opacity(0.2))
              .cornerRadius(12)
          }
          .disabled(store.state.locationHistory.isEmpty)
        }
        .padding(.horizontal)
        .padding(.bottom)
      }
    }
    .navigationTitle("Location Tracking")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      // Request authorization on appear
      if store.state.authorizationStatus == .notDetermined {
        store.send(.requestAuthorization)
      }
      store.send(.updateAuthorizationStatus)
    }
    .onChange(of: store.state.currentLocation) { _, newLocation in
      // Update camera to follow current location
      if let location = newLocation, store.state.isTracking {
        withAnimation {
          cameraPosition = .camera(
            MapCamera(
              centerCoordinate: location.coordinate,
              distance: 1000,  // 1km zoom
              heading: 0,
              pitch: 0
            )
          )
        }
      }
    }
  }
}

// MARK: - Status Card

struct StatusCard: View {
  let isTracking: Bool
  let locationCount: Int
  let currentLocation: CLLocation?
  let errorMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Circle()
          .fill(isTracking ? Color.green : Color.gray)
          .frame(width: 12, height: 12)
        Text(isTracking ? "Tracking Active" : "Tracking Stopped")
          .font(.headline)
      }

      if let location = currentLocation {
        VStack(alignment: .leading, spacing: 4) {
          Text(
            "📍 \(String(format: "%.6f, %.6f", location.coordinate.latitude, location.coordinate.longitude))"
          )
          .font(.system(.body, design: .monospaced))
          Text("⚡️ \(String(format: "%.1f m accuracy", location.horizontalAccuracy))")
            .font(.caption)
            .foregroundColor(.secondary)
          Text("📊 \(locationCount) points recorded")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      if let error = errorMessage {
        Text("⚠️ \(error)")
          .font(.caption)
          .foregroundColor(.red)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(Color.white.opacity(0.3))
    .cornerRadius(12)
  }
}

// MARK: - Preview

#Preview {
  NavigationStack {
    LocationTrackingView()
  }
}
