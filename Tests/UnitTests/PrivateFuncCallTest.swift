import Flow
import Foundation
import Observation
import Testing

/// Test: Can we call private functions from run blocks?
@MainActor
@Suite struct PrivateFuncCallTests {
  // MARK: - Test Feature with Private Helper

  struct TestFeature: Feature {
    @Observable
    final class State {
      var value: String = ""
      var processedValue: String = ""
    }

    enum Action: Sendable {
      case processValue(String)
    }

    // Private helper function
    private func formatValue(_ input: String) -> String {
      "Formatted: \(input.uppercased())"
    }

    func handle() -> ActionHandler<Action, State, Void> {
      ActionHandler { [self] action, state in
        switch action {
        case .processValue(let input):
          state.value = input
          return .run { state in
            // Can we call private func here?
            let formatted = self.formatValue(input)
            state.processedValue = formatted
          }
        }
      }
    }
  }

  @Test func canCallPrivateFuncFromRunBlock() async {
    let store = Store(
      initialState: TestFeature.State(),
      feature: TestFeature()
    )

    await store.send(.processValue("hello")).value

    #expect(store.state.value == "hello")
    #expect(store.state.processedValue == "Formatted: HELLO")
  }
}
