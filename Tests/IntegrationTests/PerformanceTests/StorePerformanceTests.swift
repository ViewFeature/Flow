import Foundation
import Testing

@testable import Flow

/// Performance tests for Store and related components.
///
/// Tests throughput, latency, and resource usage under load.
@MainActor
@Suite struct StorePerformanceTests {
  // MARK: - Test Fixtures

  enum PerformanceAction: Sendable {
    case increment
    case batchIncrement(Int)
    case heavyComputation
    case lightTask
  }

  @Observable
  final class PerformanceState {
    var counter: Int = 0
    var operations: Int = 0

    init(counter: Int = 0, operations: Int = 0) {
      self.counter = counter
      self.operations = operations
    }
  }

  struct PerformanceFeature: Feature, Sendable {
    typealias Action = PerformanceAction
    typealias State = PerformanceState

    func handle() -> ActionHandler<Action, State, Void> {
      ActionHandler { action, state in
        switch action {
        case .increment:
          state.counter += 1
          state.operations += 1
          return .none

        case .batchIncrement(let count):
          state.counter += count
          state.operations += 1
          return .none

        case .heavyComputation:
          state.operations += 1
          return .run { _ in
            // Simulate heavy work
            try await Task.sleep(for: .milliseconds(5))
          }

        case .lightTask:
          state.operations += 1
          return .run { _ in
            try await Task.sleep(for: .milliseconds(1))
          }
        }
      }
    }
  }

  // MARK: - Complex State Test Fixtures

  @Observable
  final class ComplexState {
    var array: [Int] = []
    var dict: [String: Int] = [:]
    var counter: Int = 0

    init(array: [Int] = [], dict: [String: Int] = [:], counter: Int = 0) {
      self.array = array
      self.dict = dict
      self.counter = counter
    }
  }

  enum ComplexAction: Sendable {
    case addToArray(Int)
    case addToDict(String, Int)
    case increment
  }

  struct ComplexFeature: Feature, Sendable {
    typealias Action = ComplexAction
    typealias State = ComplexState

    func handle() -> ActionHandler<Action, State, Void> {
      ActionHandler { action, state in
        switch action {
        case .addToArray(let value):
          state.array.append(value)
          return .none
        case .addToDict(let key, let value):
          state.dict[key] = value
          return .none
        case .increment:
          state.counter += 1
          return .none
        }
      }
    }
  }

  // MARK: - Throughput Tests

  @Test func highVolumeActionProcessing() async {
    // GIVEN: Store
    let sut = Store(
      initialState: PerformanceState(),
      feature: PerformanceFeature()
    )

    // WHEN: Process many actions
    let actionCount = 1000
    let startTime = Date()

    for _ in 0..<actionCount {
      await sut.send(.increment).value
    }

    let duration = Date().timeIntervalSince(startTime)

    // THEN: Should process efficiently
    #expect(sut.state.counter == actionCount)
    #expect(
      duration < 10.0, "Processing \(actionCount) actions took too long: \(duration)s")

    let throughput = Double(actionCount) / duration
    print("Throughput: \(Int(throughput)) actions/second")
  }

  @Test func batchOperationPerformance() async {
    // GIVEN: Store
    let sut = Store(
      initialState: PerformanceState(),
      feature: PerformanceFeature()
    )

    // WHEN: Batch operations
    let batchSize = 100
    let batchCount = 100
    let startTime = Date()

    for _ in 0..<batchCount {
      await sut.send(.batchIncrement(batchSize)).value
    }

    let duration = Date().timeIntervalSince(startTime)

    // THEN: Should be faster than individual operations
    #expect(sut.state.counter == batchSize * batchCount)

    // iOS Simulator is significantly slower than native macOS
    #if targetEnvironment(simulator)
      let timeout: TimeInterval = 7.0  // iOS Simulator
    #else
      let timeout: TimeInterval = 6.0  // Native macOS
    #endif
    #expect(duration < timeout, "Batch processing took too long: \(duration)s")
  }

  // MARK: - Concurrent Action Tests

  @Test func concurrentActionPerformance() async {
    // GIVEN: Store
    let sut = Store(
      initialState: PerformanceState(),
      feature: PerformanceFeature()
    )

    // WHEN: Send many actions concurrently
    let actionCount = 500
    let startTime = Date()

    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<actionCount {
        group.addTask {
          await sut.send(.increment).value
        }
      }
    }

    let duration = Date().timeIntervalSince(startTime)

    // THEN: All actions should be processed
    #expect(sut.state.counter == actionCount)
    #expect(duration < 10.0, "Concurrent processing took too long: \(duration)s")

    print("Concurrent processing: \(Int(Double(actionCount) / duration)) actions/second")
  }

  // MARK: - Task Management Performance

  @Test func manyLightTasksPerformance() async {
    // GIVEN: Store
    let sut = Store(
      initialState: PerformanceState(),
      feature: PerformanceFeature()
    )

    // WHEN: Create many light tasks (sequential processing)
    let taskCount = 100
    let startTime = Date()

    var lastTask: Task<Result<Void, Error>, Never>?
    for _ in 0..<taskCount {
      lastTask = sut.send(.lightTask)
    }

    // Wait for all tasks to complete (sequential execution ensures order)
    await lastTask?.value

    let duration = Date().timeIntervalSince(startTime)

    // THEN: Should handle tasks efficiently
    #expect(sut.state.operations == taskCount)
    #expect(duration < 5.0, "Light task processing took too long: \(duration)s")
  }

  @Test func automaticTaskCancellationPerformance() async {
    // GIVEN: Store with many running tasks
    let startTime: Date
    let duration: TimeInterval

    do {
      let store = Store(
        initialState: PerformanceState(),
        feature: PerformanceFeature()
      )

      // Start many tasks
      for _ in 0..<100 {
        _ = store.send(.heavyComputation)
      }

      // NOTE: Give tasks time to start before deinit
      try? await Task.sleep(for: .milliseconds(10))

      // WHEN: Store goes out of scope (automatic cancellation via deinit)
      startTime = Date()
    }

    // ⚠️ ISOLATED DEINIT TIMING DEPENDENCY (SE-0371) ⚠️
    //
    // This performance test has inherent limitations due to isolated deinit.
    // The Task.sleep below is necessary but affects measurement accuracy.
    //
    // Why this sleep exists:
    // - Store's isolated deinit must complete on MainActor
    // - 100 tasks must be cancelled
    // - We need to measure the total time, but deinit timing is non-deterministic
    //
    // Limitations:
    // - The 50ms sleep is included in the measured duration
    // - Actual cancellation may complete before or after the sleep
    // - Cannot accurately measure pure cancellation performance
    // - May fail in very slow CI environments if deinit takes >1000ms
    //
    // Interpretation:
    // This test verifies that cancellation + deinit completes within 1 second,
    // but the exact cancellation performance cannot be isolated from deinit overhead.
    //
    // Future improvement:
    // Consider redesigning this as a functional test rather than performance test,
    // or removing it entirely due to measurement unreliability.
    try? await Task.sleep(for: .milliseconds(50))
    duration = Date().timeIntervalSince(startTime)

    // THEN: Automatic cancellation should be fast
    #expect(duration < 1.0, "Automatic task cancellation took too long: \(duration)s")
  }

  // MARK: - Memory Performance Tests

  @Test func memoryUsageUnderLoad() async {
    // GIVEN: Store
    let sut = Store(
      initialState: PerformanceState(),
      feature: PerformanceFeature()
    )

    // WHEN: Process many actions
    for _ in 0..<10_000 {
      await sut.send(.increment).value
    }

    // THEN: Memory should not grow unbounded
    #expect(sut.state.counter == 10_000)
    // Note: Actual memory testing would require more sophisticated tooling
  }

  // MARK: - State Update Performance

  @Test func rapidStateUpdates() async {
    // GIVEN: Store with complex state
    let sut = Store(
      initialState: ComplexState(),
      feature: ComplexFeature()
    )

    // WHEN: Perform many state updates
    let startTime = Date()

    for index in 0..<1000 {
      await sut.send(.addToArray(index)).value
      await sut.send(.addToDict("key\(index)", index)).value
      await sut.send(.increment).value
    }

    let duration = Date().timeIntervalSince(startTime)

    // THEN: Updates should be efficient
    #expect(sut.state.array.count == 1000)
    #expect(sut.state.dict.count == 1000)
    #expect(sut.state.counter == 1000)
    #expect(duration < 10.0, "State updates took too long: \(duration)s")
  }

  // MARK: - XCTest Performance Measurements

  @Test func measureActionProcessing() async {
    // GIVEN: Store
    let sut = Store(
      initialState: PerformanceState(),
      feature: PerformanceFeature()
    )

    // WHEN: Measure action processing
    // Note: XCTestCase.measure doesn't work well with async/await
    // Using manual measurement instead
    let iterations = 5
    var durations: [TimeInterval] = []

    for _ in 0..<iterations {
      let start = Date()
      for _ in 0..<100 {
        await sut.send(.increment).value
      }
      let duration = Date().timeIntervalSince(start)
      durations.append(duration)
    }

    let avgDuration = durations.reduce(0, +) / Double(durations.count)

    // THEN: Baseline established
    #expect(avgDuration < 2.0, "Average processing time too long: \(avgDuration)s")
  }

  @Test func measureStateAccess() async {
    // GIVEN: Store with data
    let sut = Store(
      initialState: PerformanceState(counter: 1000),
      feature: PerformanceFeature()
    )

    // WHEN: Measure state access (manual measurement for MainActor compatibility)
    let iterations = 10
    var durations: [TimeInterval] = []

    for _ in 0..<iterations {
      let start = Date()
      var sum = 0
      for _ in 0..<10_000 {
        sum += sut.state.counter
      }
      let duration = Date().timeIntervalSince(start)
      durations.append(duration)
      #expect(sum > 0)
    }

    let avgDuration = durations.reduce(0, +) / Double(durations.count)

    // THEN: State access should be fast
    #expect(avgDuration < 0.1, "Average state access time too long: \(avgDuration)s")
    print("State access performance: \(String(format: "%.6f", avgDuration))s average")
  }

  // MARK: - Scalability Tests

  @Test func scalabilityWithMultipleStores() async {
    // GIVEN: Multiple stores
    let storeCount = 10
    var stores: [Store<PerformanceFeature>] = []

    for _ in 0..<storeCount {
      stores.append(
        Store(
          initialState: PerformanceState(),
          feature: PerformanceFeature()
        ))
    }

    // WHEN: Process actions across all stores
    let startTime = Date()

    for store in stores {
      for _ in 0..<100 {
        await store.send(.increment).value
      }
    }

    let duration = Date().timeIntervalSince(startTime)

    // THEN: All stores should process correctly
    for store in stores {
      #expect(store.state.counter == 100)
    }
    #expect(duration < 10.0, "Multiple store processing took too long: \(duration)s")
  }

  // MARK: - Real-World Scenario Tests

  @Test func realisticWorkloadPerformance() async {
    // GIVEN: Store
    let sut = Store(
      initialState: PerformanceState(),
      feature: PerformanceFeature()
    )

    // WHEN: Simulate realistic workload (sequential processing)
    // 80% simple actions, 20% with tasks
    let startTime = Date()

    var lastTask: Task<Result<Void, Error>, Never>?
    for index in 0..<500 {
      if index % 5 == 0 {
        lastTask = sut.send(.heavyComputation)
      } else {
        lastTask = sut.send(.increment)
        await lastTask!.value
      }
    }

    // Wait for last task to complete (sequential execution ensures all tasks complete)
    await lastTask?.value

    let duration = Date().timeIntervalSince(startTime)

    // THEN: Should handle mixed workload efficiently
    #expect(sut.state.operations >= 500)
    #expect(duration < 10.0, "Realistic workload took too long: \(duration)s")

    print("Realistic workload completed in \(String(format: "%.2f", duration))s")
  }

  // MARK: - Stress Tests

  @Test func extremeLoadStressTest() async {
    // GIVEN: Store
    let sut = Store(
      initialState: PerformanceState(),
      feature: PerformanceFeature()
    )

    // WHEN: Apply extreme load
    let actionCount = 5000
    let startTime = Date()

    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<actionCount {
        group.addTask {
          await sut.send(.increment).value
        }
      }
    }

    let duration = Date().timeIntervalSince(startTime)

    // THEN: System should remain stable
    #expect(sut.state.counter == actionCount)
    print("Extreme load test: \(actionCount) actions in \(String(format: "%.2f", duration))s")
  }
}
