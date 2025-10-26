import Flow
import Foundation
import Observation

struct CounterFeature: Feature {
  // MARK: - State

  @Observable
  final class State {
    var count: Int = 0
    var isLoading: Bool = false

    init(count: Int = 0, isLoading: Bool = false) {
      self.count = count
      self.isLoading = isLoading
    }
  }

  // MARK: - Action

  enum Action: Sendable {
    case increment
    case decrement
    case reset
    case delayedIncrement
    case cancelDelayedIncrement
    case finishLoading
  }

  // MARK: - Handler

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

      case .delayedIncrement:
        state.isLoading = true
        return .run { state in
          try await Task.sleep(for: .seconds(3))
          // Check if task was cancelled during sleep
          try Task.checkCancellation()
          state.count += 1
          state.isLoading = false
        }
        .cancellable(id: "delayed-increment")
        .catch { _, state in
          state.isLoading = false
        }

      case .cancelDelayedIncrement:
        state.isLoading = false
        return .cancel(id: "delayed-increment")

      case .finishLoading:
        state.isLoading = false
        return .none
      }
    }
  }
}
