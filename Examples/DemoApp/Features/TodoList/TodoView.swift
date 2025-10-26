import Flow
import SwiftUI

struct TodoView: View {
  @State private var store = Store(
    initialState: TodoFeature.State(),
    feature: TodoFeature()
  )

  var body: some View {
    VStack(spacing: 0) {
      // Add todo section
      HStack {
        TextField(
          "New todo",
          text: Binding(
            get: { store.state.newTodoText },
            set: { store.send(.updateNewTodoText($0)) }
          )
        )
        .textFieldStyle(.roundedBorder)
        .onSubmit {
          store.send(.addTodo)
        }

        Button {
          store.send(.addTodo)
        } label: {
          Image(systemName: "plus.circle.fill")
            .font(.system(size: 28))
        }
        .buttonStyle(.plain)
        .disabled(store.state.newTodoText.isEmpty)
      }
      .padding()

      Divider()

      // Todo list
      if store.state.todos.isEmpty {
        ContentUnavailableView(
          "No Todos",
          systemImage: "checkmark.circle",
          description: Text("Add a new todo to get started")
        )
      } else {
        List {
          ForEach(store.state.todos) { todo in
            HStack {
              Button {
                store.send(.toggleTodo(id: todo.id))
              } label: {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                  .font(.system(size: 22))
                  .foregroundStyle(todo.isCompleted ? .green : .secondary)
              }
              .buttonStyle(.plain)

              Text(todo.title)
                .strikethrough(todo.isCompleted)
                .foregroundStyle(todo.isCompleted ? .secondary : .primary)

              Spacer()
            }
            .padding(.vertical, 4)
          }
          .onDelete { indexSet in
            for index in indexSet {
              store.send(.deleteTodo(id: store.state.todos[index].id))
            }
          }
        }
        .listStyle(.plain)
      }
    }
    .navigationTitle("Todo List")
  }
}

#Preview {
  NavigationStack {
    TodoView()
  }
}
