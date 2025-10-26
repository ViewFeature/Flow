import Flow
import SwiftUI

struct CounterView: View {
  @State private var store = Store(
    initialState: CounterFeature.State(),
    feature: CounterFeature()
  )

  var body: some View {
    VStack(spacing: 30) {
      Text("\(store.state.count)")
        .font(.system(size: 80, weight: .bold, design: .rounded))
        .foregroundStyle(.primary)
        .contentTransition(.numericText())

      VStack(spacing: 15) {
        HStack(spacing: 15) {
          Button {
            store.send(.decrement)
          } label: {
            Image(systemName: "minus.circle.fill")
              .font(.system(size: 50))
          }
          .buttonStyle(.plain)

          Button {
            store.send(.increment)
          } label: {
            Image(systemName: "plus.circle.fill")
              .font(.system(size: 50))
          }
          .buttonStyle(.plain)
        }

        Button {
          store.send(.reset)
        } label: {
          Text("Reset")
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.secondary.opacity(0.2))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)

        // Action経由でタスクを開始（推奨パターン）
        Button {
          Task {
            await store.send(.delayedIncrement).value
          }
        } label: {
          HStack {
            if store.state.isLoading {
              ProgressView()
                .progressViewStyle(.circular)
            }
            Text("Delayed +1 (3s)")
          }
          .frame(maxWidth: .infinity)
          .padding()
          .background(Color.blue.opacity(0.2))
          .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(store.state.isLoading)

        // Action経由でタスクをキャンセル（推奨パターン）
        Button {
          store.send(.cancelDelayedIncrement)
        } label: {
          Text("Cancel Task")
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.2))
            .foregroundColor(.red)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(!store.state.isLoading)
      }
      .padding(.horizontal, 40)
    }
    .navigationTitle("Counter")
    // Note: タスクは自動的にクリーンアップされます
    // View が破棄されると Store も解放され、TaskManager.deinit により
    // 実行中のすべてのタスクが自動的にキャンセルされます
  }
}

#Preview {
  NavigationStack {
    CounterView()
  }
}
