import Foundation
import Testing

@testable import Flow

/// End-to-end tests for complete Store workflows.
///
/// Tests full user scenarios where Store, ActionHandler, Middleware, and TaskManager
/// work together to handle complex application flows.
@MainActor
@Suite struct StoreFullWorkflowTests {
  // MARK: - Test Fixtures

  enum UserAction: Sendable {
    case loadUser(String)
    case updateProfile(name: String, email: String)
    case logout
    case refreshData
    case cancelLoad
  }

  @Observable
  final class UserState {
    var userId: String?
    var userName: String?
    var userEmail: String?
    var isLoading: Bool = false
    var isLoggedIn: Bool = false
    var errorMessage: String?
    var refreshCount: Int = 0

    init(
      userId: String? = nil, userName: String? = nil, userEmail: String? = nil,
      isLoading: Bool = false, isLoggedIn: Bool = false, errorMessage: String? = nil,
      refreshCount: Int = 0
    ) {
      self.userId = userId
      self.userName = userName
      self.userEmail = userEmail
      self.isLoading = isLoading
      self.isLoggedIn = isLoggedIn
      self.errorMessage = errorMessage
      self.refreshCount = refreshCount
    }
  }

  struct UserFeature: Feature, Sendable {
    typealias Action = UserAction
    typealias State = UserState

    func handle() -> ActionHandler<Action, State, Void> {
      ActionHandler { action, state in
        switch action {
        case .loadUser(let id):
          state.isLoading = true
          state.userId = id
          return .run { _ in
            // Simulate network request
            try await Task.sleep(for: .milliseconds(50))
          }

        case .updateProfile(let name, let email):
          state.userName = name
          state.userEmail = email
          state.isLoggedIn = true
          state.isLoading = false
          return .none

        case .logout:
          state.userId = nil
          state.userName = nil
          state.userEmail = nil
          state.isLoading = false
          state.isLoggedIn = false
          state.errorMessage = nil
          state.refreshCount = 0
          return .cancel(id: "loadUser")

        case .refreshData:
          state.refreshCount += 1
          return .run { _ in
            try await Task.sleep(for: .milliseconds(20))
          }

        case .cancelLoad:
          state.isLoading = false
          return .cancel(id: "loadUser")
        }
      }
    }
  }

  // MARK: - Login Workflow Tests

  @Test func fullLoginWorkflow() async {
    // GIVEN: Store with initial state
    let sut = Store(
      initialState: UserState(),
      feature: UserFeature()
    )

    // WHEN: Execute full login workflow
    // Step 1: Load user
    await sut.send(.loadUser("user123")).value
    #expect(sut.state.isLoading)
    #expect(sut.state.userId == "user123")

    // Step 2: Update profile
    await sut.send(.updateProfile(name: "John Doe", email: "john@example.com")).value
    #expect(sut.state.userName == "John Doe")
    #expect(sut.state.userEmail == "john@example.com")
    #expect(sut.state.isLoggedIn)
    #expect(!sut.state.isLoading)

    // THEN: User should be fully logged in
    #expect(sut.state.userId == "user123")
    #expect(sut.state.isLoggedIn)
  }

  @Test func logoutCancelsOngoingLoad() async {
    // GIVEN: Store with ongoing load
    let sut = Store(
      initialState: UserState(),
      feature: UserFeature()
    )

    // Start loading user (fire-and-forget)
    let loadTask = sut.send(.loadUser("user456"))
    await Task.yield()  // Give task time to start
    #expect(sut.state.isLoading)

    // WHEN: Logout while loading
    await sut.send(.logout).value
    await loadTask.value  // Wait for cancelled task to complete

    // THEN: State should be reset and task cancelled
    #expect(!sut.state.isLoading)
    #expect(!sut.state.isLoggedIn)
    #expect(sut.state.userId == nil)
    #expect(sut.state.userName == nil)
  }

  // MARK: - Multi-Action Workflows

  @Test func multipleSequentialActions() async {
    // GIVEN: Store
    let sut = Store(
      initialState: UserState(),
      feature: UserFeature()
    )

    // WHEN: Execute multiple sequential actions
    await sut.send(.loadUser("user789")).value
    await sut.send(.updateProfile(name: "Jane Doe", email: "jane@example.com")).value
    await sut.send(.refreshData).value
    await sut.send(.refreshData).value

    // THEN: All actions should be processed (no sleep needed - sequential execution ensures order)
    #expect(sut.state.userId == "user789")
    #expect(sut.state.userName == "Jane Doe")
    #expect(sut.state.refreshCount == 2)
    #expect(sut.state.isLoggedIn)
  }

  @Test func complexStateTransitions() async {
    // GIVEN: Store
    let sut = Store(
      initialState: UserState(),
      feature: UserFeature()
    )

    // WHEN: Execute complex state transitions (all sequential)
    // Load -> Cancel -> Load -> Update -> Refresh -> Logout
    await sut.send(.loadUser("user1")).value

    await sut.send(.cancelLoad).value
    #expect(!sut.state.isLoading)

    await sut.send(.loadUser("user2")).value
    await sut.send(.updateProfile(name: "User 2", email: "user2@example.com")).value
    await sut.send(.refreshData).value

    await sut.send(.logout).value

    // THEN: Should end in clean state (no sleep needed - sequential execution)
    #expect(!sut.state.isLoggedIn)
    #expect(sut.state.userId == nil)
  }

  // MARK: - Concurrent Actions

  @Test func concurrentActionProcessing() async {
    // GIVEN: Store
    let sut = Store(
      initialState: UserState(),
      feature: UserFeature()
    )

    // WHEN: Send multiple actions concurrently
    let task1 = sut.send(.loadUser("user1"))
    let task2 = sut.send(.updateProfile(name: "Test", email: "test@example.com"))
    let task3 = sut.send(.refreshData)

    await task1.value
    await task2.value
    await task3.value

    // THEN: All actions should be processed (await .value ensures completion)
    #expect(sut.state.userName == "Test")
    #expect(sut.state.isLoggedIn)
    #expect(sut.state.refreshCount >= 1)
  }

  // NOTE: Task Cancellation Workflows
  // automatic cancellation on deinit is verified via code review of TaskManager.isolated deinit
  // SE-0371 isolated deinit makes weak reference timing non-deterministic and untestable

  // MARK: - Data Refresh Workflows

  @Test func repeatedRefreshes() async {
    // GIVEN: Store
    let sut = Store(
      initialState: UserState(),
      feature: UserFeature()
    )

    // WHEN: Perform multiple refreshes (sequential execution)
    for _ in 0..<5 {
      await sut.send(.refreshData).value
    }

    // THEN: All refreshes should be counted (no sleep needed - await .value ensures order)
    #expect(sut.state.refreshCount == 5)
  }

  // MARK: - State Consistency Tests

  @Test func stateConsistencyDuringWorkflow() async {
    // GIVEN: Store
    let sut = Store(
      initialState: UserState(),
      feature: UserFeature()
    )

    // WHEN: Execute workflow and check consistency at each step
    await sut.send(.loadUser("user123")).value
    #expect(sut.state.isLoading)
    #expect(sut.state.userName == nil)  // Should be nil before update

    await sut.send(.updateProfile(name: "Test User", email: "test@example.com")).value
    #expect(!sut.state.isLoading)
    #expect(sut.state.userName != nil)
    #expect(sut.state.isLoggedIn)

    let userId = sut.state.userId
    let userName = sut.state.userName

    await sut.send(.refreshData).value

    // THEN: User data should remain consistent after refresh
    #expect(sut.state.userId == userId)
    #expect(sut.state.userName == userName)
  }
}
