import SwiftUI

struct ContentView: View {
  var body: some View {
    NavigationStack {
      List {
        Section("Basic Examples") {
          NavigationLink("Counter") {
            CounterView()
          }

          NavigationLink("Todo List") {
            TodoView()
          }
        }

        Section("Advanced Examples") {
          NavigationLink("User Management") {
            UserView()
          }

          NavigationLink("Location Tracking") {
            LocationTrackingView()
          }
        }
      }
      .navigationTitle("Flow Demo")
    }
  }
}

#Preview {
  ContentView()
}
