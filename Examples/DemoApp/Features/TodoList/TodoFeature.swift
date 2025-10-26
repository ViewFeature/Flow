import Flow
import Foundation
import Observation

// MARK: - Models

struct TodoItem: Identifiable, Equatable, Sendable {
  let id: UUID
  var title: String
  var isCompleted: Bool

  init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
    self.id = id
    self.title = title
    self.isCompleted = isCompleted
  }
}

// MARK: - Feature

struct TodoFeature: Feature {
  // MARK: - State

  @Observable
  final class State {
    var todos: [TodoItem] = []
    var newTodoText: String = ""

    init(todos: [TodoItem] = [], newTodoText: String = "") {
      self.todos = todos
      self.newTodoText = newTodoText
    }
  }

  // MARK: - Action

  enum Action: Sendable {
    case addTodo
    case toggleTodo(id: UUID)
    case deleteTodo(id: UUID)
    case updateNewTodoText(String)
  }

  // MARK: - Handler

  func handle() -> ActionHandler<Action, State, Void> {
    ActionHandler { action, state in
      switch action {
      case .addTodo:
        guard !state.newTodoText.isEmpty else {
          return .none
        }
        let newTodo = TodoItem(title: state.newTodoText)
        state.todos.append(newTodo)
        state.newTodoText = ""
        return .none

      case .toggleTodo(let id):
        if let index = state.todos.firstIndex(where: { $0.id == id }) {
          state.todos[index].isCompleted.toggle()
        }
        return .none

      case .deleteTodo(let id):
        state.todos.removeAll { $0.id == id }
        return .none

      case .updateNewTodoText(let text):
        state.newTodoText = text
        return .none
      }
    }
  }
}
