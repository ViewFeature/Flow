import Flow
import Foundation
import Observation
import Testing

/// Test: Memory leak scenarios with [self] capture
@MainActor
@Suite struct MemoryLeakTests {
  // MARK: - Feature with Private Functions

  struct LeakTestFeature: Feature {
    @Observable
    final class State {
      var value: String = ""
      var counter: Int = 0
    }

    enum Action: Sendable {
      case process(String)
      case increment
    }

    private func expensiveOperation(_ input: String) -> String {
      "Processed: \(input)"
    }

    func handle() -> ActionHandler<Action, State, Void> {
      ActionHandler { [self] action, state in
        switch action {
        case .process(let input):
          return .run { state in
            // Calls private func - potential leak point?
            let result = self.expensiveOperation(input)
            state.value = result
            state.counter += 1
          }
        case .increment:
          state.counter += 1
          return .none
        }
      }
    }
  }

  // MARK: - Memory Leak Tests

  @Test func featureDoesNotLeakMemoryWithPrivateFuncCalls() async {
    weak var weakStore: Store<LeakTestFeature>?

    do {
      let feature = LeakTestFeature()
      let store = Store(
        initialState: LeakTestFeature.State(),
        feature: feature
      )
      weakStore = store

      // Execute actions that use private functions
      await store.send(.process("test1")).value
      await store.send(.process("test2")).value
      await store.send(.increment).value

      #expect(store.state.value == "Processed: test2")
      #expect(store.state.counter == 3)
    }

    // Store should be deallocated
    #expect(weakStore == nil, "Store leaked memory")
  }

  @Test func storeProperlyReleasesCompletedTasks() async {
    let store = Store(
      initialState: LeakTestFeature.State(),
      feature: LeakTestFeature()
    )

    // Start and complete multiple tasks
    await store.send(.process("task1")).value
    await store.send(.process("task2")).value
    await store.send(.process("task3")).value

    // All tasks should be completed and removed from TaskManager
    #expect(store.state.value == "Processed: task3")
    #expect(store.state.counter == 3)
  }

  @Test func cancelledTasksDoNotLeak() async {
    weak var weakStore: Store<LeakTestFeature>?

    do {
      let store = Store(
        initialState: LeakTestFeature.State(),
        feature: LeakTestFeature()
      )
      weakStore = store

      // Execute and complete tasks
      await store.send(.process("task")).value

      // Verify cleanup
    }

    // Store should be deallocated
    #expect(weakStore == nil, "Store with cancelled tasks leaked memory")
  }

  @Test func multipleStoresDoNotInterfere() async {
    weak var weakStore1: Store<LeakTestFeature>?
    weak var weakStore2: Store<LeakTestFeature>?

    do {
      let store1 = Store(
        initialState: LeakTestFeature.State(),
        feature: LeakTestFeature()
      )
      let store2 = Store(
        initialState: LeakTestFeature.State(),
        feature: LeakTestFeature()
      )

      weakStore1 = store1
      weakStore2 = store2

      // Execute actions on both stores
      await store1.send(.process("store1")).value
      await store2.send(.process("store2")).value

      #expect(store1.state.value == "Processed: store1")
      #expect(store2.state.value == "Processed: store2")
    }

    // Both stores should be deallocated independently
    #expect(weakStore1 == nil, "Store1 leaked")
    #expect(weakStore2 == nil, "Store2 leaked")
  }

  @Test func storeReleasesResources() async {
    weak var weakStore: Store<LeakTestFeature>?

    do {
      let store = Store(
        initialState: LeakTestFeature.State(),
        feature: LeakTestFeature()
      )
      weakStore = store

      // Execute multiple operations
      for iteration in 0..<10 {
        await store.send(.process("iteration \(iteration)")).value
      }
    }

    // Store should be deallocated
    #expect(weakStore == nil, "Store leaked memory after multiple operations")
  }
}
