import Foundation
import Testing

@testable import Flow

/// Integration tests for Store and ActionHandler interaction.
///
/// Tests how Store and ActionHandler work together to process actions
/// and manage state transitions.
@MainActor
@Suite struct StoreActionHandlerIntegrationTests {
  // MARK: - Test Fixtures

  enum TodoAction: Sendable {
    case add(String)
    case complete(Int)
    case delete(Int)
    case toggleAll
    case clearCompleted
  }

  struct Todo: Equatable, Sendable {
    let id: Int
    var title: String
    var isCompleted: Bool
  }

  @Observable
  final class TodoState {
    var todos: [Todo] = []
    var nextId: Int = 1

    init(todos: [Todo] = [], nextId: Int = 1) {
      self.todos = todos
      self.nextId = nextId
    }
  }

  struct TodoFeature: Feature, Sendable {
    typealias Action = TodoAction
    typealias State = TodoState

    func handle() -> ActionHandler<Action, State, Void> {
      ActionHandler { action, state in
        switch action {
        case .add(let title):
          let todo = Todo(id: state.nextId, title: title, isCompleted: false)
          state.todos.append(todo)
          state.nextId += 1
          return .none

        case .complete(let id):
          if let index = state.todos.firstIndex(where: { $0.id == id }) {
            state.todos[index].isCompleted = true
          }
          return .none

        case .delete(let id):
          state.todos.removeAll { $0.id == id }
          return .none

        case .toggleAll:
          let allCompleted = state.todos.allSatisfy(\.isCompleted)
          for index in state.todos.indices {
            state.todos[index].isCompleted = !allCompleted
          }
          return .none

        case .clearCompleted:
          state.todos.removeAll { $0.isCompleted }
          return .none
        }
      }
    }
  }

  // MARK: - Basic Integration Tests

  @Test func storeAndHandlerProcessSimpleAction() async {
    // GIVEN: Store with TodoFeature
    let sut = Store(
      initialState: TodoState(),
      feature: TodoFeature()
    )

    // WHEN: Send add action
    await sut.send(.add("Buy milk")).value

    // THEN: State should be updated
    #expect(sut.state.todos.count == 1)
    #expect(sut.state.todos[0].title == "Buy milk")
    #expect(sut.state.todos[0].id == 1)
    #expect(!sut.state.todos[0].isCompleted)
  }

  @Test func storeAndHandlerProcessMultipleActions() async {
    // GIVEN: Store
    let sut = Store(
      initialState: TodoState(),
      feature: TodoFeature()
    )

    // WHEN: Send multiple add actions
    await sut.send(.add("Task 1")).value
    await sut.send(.add("Task 2")).value
    await sut.send(.add("Task 3")).value

    // THEN: All tasks should be added
    #expect(sut.state.todos.count == 3)
    #expect(sut.state.todos[0].title == "Task 1")
    #expect(sut.state.todos[1].title == "Task 2")
    #expect(sut.state.todos[2].title == "Task 3")
  }

  // MARK: - State Mutation Tests

  @Test func handlerMutatesStateCorrectly() async {
    // GIVEN: Store with todos
    let sut = Store(
      initialState: TodoState(),
      feature: TodoFeature()
    )

    await sut.send(.add("Task 1")).value
    await sut.send(.add("Task 2")).value

    // WHEN: Complete a task
    await sut.send(.complete(1)).value

    // THEN: Task should be marked completed
    #expect(sut.state.todos[0].isCompleted)
    #expect(!sut.state.todos[1].isCompleted)
  }

  @Test func handlerDeletesCorrectly() async {
    // GIVEN: Store with multiple todos
    let sut = Store(
      initialState: TodoState(),
      feature: TodoFeature()
    )

    await sut.send(.add("Task 1")).value
    await sut.send(.add("Task 2")).value
    await sut.send(.add("Task 3")).value

    // WHEN: Delete middle task
    await sut.send(.delete(2)).value

    // THEN: Task 2 should be removed
    #expect(sut.state.todos.count == 2)
    #expect(sut.state.todos[0].title == "Task 1")
    #expect(sut.state.todos[1].title == "Task 3")
  }

  // MARK: - Complex State Transitions

  @Test func toggleAllWithMixedCompletionStates() async {
    // GIVEN: Store with mixed completion states
    let sut = Store(
      initialState: TodoState(),
      feature: TodoFeature()
    )

    await sut.send(.add("Task 1")).value
    await sut.send(.add("Task 2")).value
    await sut.send(.add("Task 3")).value
    await sut.send(.complete(1)).value

    // WHEN: Toggle all
    await sut.send(.toggleAll).value

    // THEN: All should be completed (not all were completed before)
    let allCompleted = sut.state.todos.allSatisfy { $0.isCompleted }
    #expect(allCompleted)

    // WHEN: Toggle all again
    await sut.send(.toggleAll).value

    // THEN: All should be uncompleted
    let allUncompleted = sut.state.todos.allSatisfy { !$0.isCompleted }
    #expect(allUncompleted)
  }

  @Test func clearCompletedRemovesOnlyCompletedTasks() async {
    // GIVEN: Store with mixed completion states
    let sut = Store(
      initialState: TodoState(),
      feature: TodoFeature()
    )

    await sut.send(.add("Task 1")).value
    await sut.send(.add("Task 2")).value
    await sut.send(.add("Task 3")).value
    await sut.send(.complete(1)).value
    await sut.send(.complete(3)).value

    // WHEN: Clear completed
    await sut.send(.clearCompleted).value

    // THEN: Only uncompleted task should remain
    #expect(sut.state.todos.count == 1)
    #expect(sut.state.todos[0].title == "Task 2")
    #expect(!sut.state.todos[0].isCompleted)
  }

  // MARK: - Action Handler Workflow Tests

  @Test func complexTodoWorkflow() async {
    // GIVEN: Store
    let sut = Store(
      initialState: TodoState(),
      feature: TodoFeature()
    )

    // WHEN: Execute complex workflow
    // Add tasks
    await sut.send(.add("Task 1")).value
    await sut.send(.add("Task 2")).value
    await sut.send(.add("Task 3")).value
    await sut.send(.add("Task 4")).value

    // Complete some
    await sut.send(.complete(1)).value
    await sut.send(.complete(2)).value

    // Delete one
    await sut.send(.delete(3)).value

    // Clear completed
    await sut.send(.clearCompleted).value

    // THEN: Only uncompleted task should remain
    #expect(sut.state.todos.count == 1)
    #expect(sut.state.todos[0].title == "Task 4")
    #expect(!sut.state.todos[0].isCompleted)
  }

  // MARK: - ID Generation Tests

  @Test func idGenerationIsSequential() async {
    // GIVEN: Store
    let sut = Store(
      initialState: TodoState(),
      feature: TodoFeature()
    )

    // WHEN: Add multiple todos
    await sut.send(.add("Task 1")).value
    await sut.send(.add("Task 2")).value
    await sut.send(.add("Task 3")).value

    // THEN: IDs should be sequential
    #expect(sut.state.todos[0].id == 1)
    #expect(sut.state.todos[1].id == 2)
    #expect(sut.state.todos[2].id == 3)
    #expect(sut.state.nextId == 4)
  }

  @Test func idGenerationAfterDeletion() async {
    // GIVEN: Store with todos
    let sut = Store(
      initialState: TodoState(),
      feature: TodoFeature()
    )

    await sut.send(.add("Task 1")).value
    await sut.send(.add("Task 2")).value
    await sut.send(.delete(1)).value

    // WHEN: Add new task
    await sut.send(.add("Task 3")).value

    // THEN: ID should continue from last nextId
    #expect(sut.state.todos.count == 2)
    #expect(sut.state.todos[1].id == 3)
  }

  // MARK: - State Consistency Tests

  @Test func stateRemainsConsistentAcrossActions() async {
    // GIVEN: Store
    let sut = Store(
      initialState: TodoState(),
      feature: TodoFeature()
    )

    // WHEN: Execute multiple actions
    await sut.send(.add("Task 1")).value
    let countAfterAdd = sut.state.todos.count
    #expect(countAfterAdd == 1)

    await sut.send(.complete(1)).value
    let countAfterComplete = sut.state.todos.count
    #expect(countAfterComplete == 1)  // Count should remain same

    await sut.send(.add("Task 2")).value
    let countAfterSecondAdd = sut.state.todos.count
    #expect(countAfterSecondAdd == 2)

    await sut.send(.clearCompleted).value
    let finalCount = sut.state.todos.count

    // THEN: State should be consistent
    #expect(finalCount == 1)
    #expect(sut.state.todos[0].title == "Task 2")
  }

  // MARK: - Edge Cases

  @Test func deleteNonexistentTask() async {
    // GIVEN: Store with one task
    let sut = Store(
      initialState: TodoState(),
      feature: TodoFeature()
    )

    await sut.send(.add("Task 1")).value

    // WHEN: Delete nonexistent task
    await sut.send(.delete(999)).value

    // THEN: No tasks should be deleted
    #expect(sut.state.todos.count == 1)
  }

  @Test func completeNonexistentTask() async {
    // GIVEN: Store with one task
    let sut = Store(
      initialState: TodoState(),
      feature: TodoFeature()
    )

    await sut.send(.add("Task 1")).value

    // WHEN: Complete nonexistent task
    await sut.send(.complete(999)).value

    // THEN: No tasks should be affected
    #expect(!sut.state.todos[0].isCompleted)
  }

  @Test func toggleAllWithEmptyList() async {
    // GIVEN: Store with no tasks
    let sut = Store(
      initialState: TodoState(),
      feature: TodoFeature()
    )

    // WHEN: Toggle all on empty list
    await sut.send(.toggleAll).value

    // THEN: Should not crash
    #expect(sut.state.todos.isEmpty)
  }

  @Test func clearCompletedWithNoCompletedTasks() async {
    // GIVEN: Store with uncompleted tasks
    let sut = Store(
      initialState: TodoState(),
      feature: TodoFeature()
    )

    await sut.send(.add("Task 1")).value
    await sut.send(.add("Task 2")).value

    // WHEN: Clear completed
    await sut.send(.clearCompleted).value

    // THEN: No tasks should be removed
    #expect(sut.state.todos.count == 2)
  }
}
