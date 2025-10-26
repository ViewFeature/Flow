import Flow
import SwiftUI

struct UserView: View {
  @State private var store = Store(
    initialState: UserFeature.State(
      users: [
        User(name: "Alice Johnson", email: "alice@example.com", role: .admin),
        User(name: "Bob Smith", email: "bob@example.com", role: .member),
        User(name: "Charlie Brown", email: "charlie@example.com", role: .guest)
      ]
    ),
    feature: UserFeature()
  )

  var filteredUsers: [User] {
    if store.state.searchText.isEmpty {
      return store.state.users
    } else {
      return store.state.users.filter {
        $0.name.localizedCaseInsensitiveContains(store.state.searchText)
          || $0.email.localizedCaseInsensitiveContains(store.state.searchText)
      }
    }
  }

  var body: some View {
    List {
      ForEach(filteredUsers) { user in
        Button {
          store.send(.selectUser(id: user.id))
        } label: {
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text(user.name)
                .font(.headline)
              Text(user.email)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(user.role.rawValue)
              .font(.caption)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(roleColor(user.role).opacity(0.2))
              .foregroundStyle(roleColor(user.role))
              .cornerRadius(8)
          }
        }
        .buttonStyle(.plain)
      }
      .onDelete { indexSet in
        for index in indexSet {
          let user = filteredUsers[index]
          store.send(.deleteUser(id: user.id))
        }
      }
    }
    .searchable(
      text: Binding(
        get: { store.state.searchText },
        set: { store.send(.updateSearchText($0)) }
      ),
      prompt: "Search users"
    )
    .navigationTitle("Users")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          Task {
            store.send(.loadUsers)
            try? await Task.sleep(for: .seconds(1.5))
            store.send(.finishLoading)
          }
        } label: {
          if store.state.isLoading {
            ProgressView()
          } else {
            Image(systemName: "arrow.clockwise")
          }
        }
        .disabled(store.state.isLoading)
      }
    }
    .sheet(
      item: Binding(
        get: { store.state.selectedUser },
        set: { newValue in
          if newValue == nil {
            store.send(.clearSelection)
          }
        }
      )
    ) { user in
      UserDetailView(user: user, store: store)
    }
  }

  private func roleColor(_ role: UserRole) -> Color {
    switch role {
    case .admin:
      return .red
    case .member:
      return .blue
    case .guest:
      return .green
    }
  }
}

struct UserDetailView: View {
  @State private var user: User
  @Environment(\.dismiss) private var dismiss
  let store: Store<UserFeature>

  init(user: User, store: Store<UserFeature>) {
    self._user = State(initialValue: user)
    self.store = store
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("User Information") {
          TextField("Name", text: $user.name)
          TextField("Email", text: $user.email)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
        }

        Section("Role") {
          Picker("Role", selection: $user.role) {
            ForEach(UserRole.allCases, id: \.self) { role in
              Text(role.rawValue).tag(role)
            }
          }
          .pickerStyle(.segmented)
        }
      }
      .navigationTitle("Edit User")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            store.send(.updateUser(user))
            dismiss()
          }
        }
      }
    }
  }
}

#Preview {
  NavigationStack {
    UserView()
  }
}
