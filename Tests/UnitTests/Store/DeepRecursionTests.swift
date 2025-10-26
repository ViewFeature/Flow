import Foundation
import Testing

@testable import Flow

/// Tests to verify that deep task composition does not cause stack overflow.
///
/// These tests demonstrate that async recursion in `executeTask()` is safe
/// because async/await uses continuation-based execution (heap) rather than
/// traditional stack-based recursion.
@MainActor
@Suite struct DeepRecursionTests {
  enum TestAction: Sendable {
    case runDeep(Int)
  }

  @Observable
  final class TestState {
    var depth = 0
    var maxDepth = 0

    init(depth: Int = 0, maxDepth: Int = 0) {
      self.depth = depth
      self.maxDepth = maxDepth
    }
  }

  struct DeepRecursionFeature: Feature, Sendable {
    typealias Action = TestAction
    typealias State = TestState

    func handle() -> ActionHandler<Action, State, Void> {
      ActionHandler { action, _ in
        switch action {
        case .runDeep(let targetDepth):
          // Build deeply nested concatenation
          return buildDeepConcatenation(current: 0, target: targetDepth)
        }
      }
    }

    @MainActor
    private func buildDeepConcatenation(current: Int, target: Int) -> ActionTask<
      Action, State, Void
    > {
      if current >= target {
        return .run { state in
          state.depth = current
          state.maxDepth = max(state.maxDepth, current)
        }
      }

      return .concatenate(
        .run { state in
          state.depth = current
          state.maxDepth = max(state.maxDepth, current)
        },
        buildDeepConcatenation(current: current + 1, target: target)
      )
    }
  }

  @Test func deepConcatenation_depth100_doesNotStackOverflow() async {
    // GIVEN: A store with deeply nested concatenation (100 levels)
    let sut = Store(
      initialState: TestState(),
      feature: DeepRecursionFeature()
    )

    // WHEN: Execute 100-level deep concatenation
    await sut.send(.runDeep(100)).value

    // THEN: Should complete successfully without stack overflow
    #expect(sut.state.maxDepth >= 100)
  }

  @Test func deepConcatenation_depth500_doesNotStackOverflow() async {
    // GIVEN: A store with very deeply nested concatenation (500 levels)
    let sut = Store(
      initialState: TestState(),
      feature: DeepRecursionFeature()
    )

    // WHEN: Execute 500-level deep concatenation
    await sut.send(.runDeep(500)).value

    // THEN: Should complete successfully without stack overflow
    // This demonstrates that async recursion uses heap, not stack
    #expect(sut.state.maxDepth >= 500)
  }
}
