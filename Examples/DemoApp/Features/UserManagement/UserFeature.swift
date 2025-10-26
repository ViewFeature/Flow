import Flow
import Foundation
import Observation

// MARK: - Models

struct User: Identifiable, Equatable, Sendable {
  let id: UUID
  var name: String
  var email: String
  var role: UserRole

  init(id: UUID = UUID(), name: String, email: String, role: UserRole = .member) {
    self.id = id
    self.name = name
    self.email = email
    self.role = role
  }
}

enum UserRole: String, CaseIterable, Sendable {
  case admin = "Admin"
  case member = "Member"
  case guest = "Guest"
}

// MARK: - Feature

struct UserFeature: Feature {
  // MARK: - State

  @Observable
  final class State {
    var users: [User]
    var selectedUser: User?
    var isLoading: Bool
    var searchText: String

    init(
      users: [User] = [], selectedUser: User? = nil, isLoading: Bool = false,
      searchText: String = ""
    ) {
      self.users = users
      self.selectedUser = selectedUser
      self.isLoading = isLoading
      self.searchText = searchText
    }
  }

  // MARK: - Action

  enum Action: Sendable {
    case selectUser(id: UUID)
    case clearSelection
    case updateUser(User)
    case deleteUser(id: UUID)
    case loadUsers
    case finishLoading
    case updateSearchText(String)
  }

  // MARK: - Handler

  func handle() -> ActionHandler<Action, State, Void> {
    ActionHandler { action, state in
      switch action {
      case .selectUser(let id):
        state.selectedUser = state.users.first { $0.id == id }
        return .none

      case .clearSelection:
        state.selectedUser = nil
        return .none

      case .updateUser(let user):
        if let index = state.users.firstIndex(where: { $0.id == user.id }) {
          state.users[index] = user
          state.selectedUser = user
        }
        return .none

      case .deleteUser(let id):
        state.users.removeAll { $0.id == id }
        if state.selectedUser?.id == id {
          state.selectedUser = nil
        }
        return .none

      case .loadUsers:
        state.isLoading = true
        // Simulate loading users
        state.users = [
          User(name: "Alice", email: "alice@example.com", role: .admin),
          User(name: "Bob", email: "bob@example.com", role: .member),
          User(name: "Charlie", email: "charlie@example.com", role: .guest),
        ]
        return .run { _ in
          try await Task.sleep(for: .seconds(1.5))
          // Task completes - View layer handles follow-up actions if needed
        }
        .cancellable(id: "load-users")
        .catch { _, state in
          state.isLoading = false
        }

      case .finishLoading:
        state.isLoading = false
        return .none

      case .updateSearchText(let text):
        state.searchText = text
        return .none
      }
    }
  }
}
