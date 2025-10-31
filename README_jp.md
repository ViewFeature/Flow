# Flow

[![Swift 6.2+](https://img.shields.io/badge/Swift-6.2+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20|%20macOS%20|%20watchOS%20|%20tvOS-blue.svg)](https://github.com/ViewFeature/Flow)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

SwiftUI向けの型安全な状態管理ライブラリです。単方向データフローアーキテクチャを採用し、ObservationとSwift 6 Concurrencyに対応しています。

<p align="center">
    <img src="flow-diagram.svg" alt="Flow Architecture Diagram" />
</p>

### カウンターアプリの実装例

```swift
import Flow
import SwiftUI

struct CounterFeature: Feature {
    @Observable
    final class State {
        var count = 0
    }

    enum Action: Sendable {
        case increment
        case decrement
    }

    func handle() -> ActionHandler<Action, State, Void> {
        ActionHandler { action, state in
            switch action {
            case .increment:
                state.count += 1
                return .none

            case .decrement:
                state.count -= 1
                return .none
            }
        }
    }
}

struct CounterView: View {
    @State private var store = Store(
        initialState: .init(),
        feature: CounterFeature()
    )

    var body: some View {
        VStack(spacing: 20) {
            Text("\(store.state.count)")
                .font(.largeTitle)

            HStack(spacing: 16) {
                Button("-") {
                    store.send(.decrement)
                }

                Button("+") {
                    store.send(.increment)
                }
            }
        }
    }
}
```

## 5つのコア原則

### 1. 単方向データフロー

すべての状態変更は一方向に流れます：**Action → Handler → State → View**。これによりアプリの動作が予測可能でデバッグしやすくなります。

```swift
Button("読み込み") {
    store.send(.load)  // Actionがhandlerに流れる
}

// Handlerが状態を更新
case .load:
    return .run { state in
        state.data = try await api.fetch()  // StateがViewに流れる
    }
```

- 予測可能なデータフロー
- 状態変更を追跡しやすい
- 明確な入力と出力

### 2. ビューローカルな状態

各ビューが`@State`で自身の状態を保持します。SwiftUIの哲学に沿った設計で、グローバルストアもストア階層もありません。

```swift
struct CounterView: View {
    @State private var store = Store(
        initialState: .init(),
        feature: CounterFeature()
    )

    var body: some View {
        VStack {
            Text("\(store.state.count)")
            Button("Increment") {
                store.send(.increment)
            }
        }
    }
}
```

- 明確なライフサイクル（StoreはViewと連動）
- グローバル状態の管理が不要
- メモリ効率的

### 3. 結果を返すアクション

アクションは型付きの結果を返すことができ、関数的なパターンを実現し、副作用を明示的にします。

```swift
enum ActionResult: Sendable {
    case saved(id: String)
}

// Handler内
case .save(let title):
    return .run { state in
        let todo = try await api.create(title: title)
        return .saved(id: todo.id)  // 結果を返す
    }

// View側
Button("保存") {
    Task {
        let result = await store.send(.save(title: title)).value
        if case .success(.saved(let id)) = result {
            await navigator.navigate(to: .detail(id: id))
        }
    }
}
```

- アクションが関数のように値を返す
- 親がナビゲーションや副作用を制御
- 型安全なコントラクト

### 4. MainActor隔離

非同期処理内で直接状態を更新できます—安全に。FlowはSwift 6の`defaultIsolation(MainActor.self)`を活用してコンパイル時の安全性を提供します。

```swift
case .fetchUser:
    state.isLoading = true
    return .run { state in
        // 非同期コンテキスト内で直接状態を更新！
        let user = try await api.fetchUser()
        state.user = user
        state.isLoading = false
    }
```

- コードの局所性（ローディング、取得、エラーが1箇所に）
- 直感的（通常のSwiftコードと同じ感覚で書ける）
- コンパイル時安全性（データ競合はコンパイル時に検出）

### 5. @Observable準拠

`@ObservableObject`や`@Published`ではなく、**SwiftUI標準の@Observable**を使用します。

```swift
@Observable
final class State {
    var count = 0  // @Publishedは不要
}
```

- Combine依存が不要
- ボイラープレートが少ない
- SwiftUIとプラットフォーム連携

## ドキュメント

📖 **[完全なドキュメント](https://viewfeature.github.io/Flow/documentation/flow/)**

- **[はじめに](https://viewfeature.github.io/Flow/documentation/flow/gettingstarted/)**
- **[コアコンセプト](https://viewfeature.github.io/Flow/documentation/flow/coreconcepts/)**
- **[コア要素](https://viewfeature.github.io/Flow/documentation/flow/coreelements/)**
- **[実践ガイド](https://viewfeature.github.io/Flow/documentation/flow/practicalguide/)**
- **[ミドルウェア](https://viewfeature.github.io/Flow/documentation/flow/middleware/)**

## インストール

### Swift Package Manager

`Package.swift`にFlowを追加：

```swift
dependencies: [
    .package(url: "https://github.com/ViewFeature/Flow.git", from: "1.3.1")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "Flow", package: "Flow")
        ],
        swiftSettings: [
            .defaultIsolation(MainActor.self)  // 推奨
        ]
    )
]
```

### Xcode

- **File → Add Package Dependencies**を選択
- 以下のURLを入力：`https://github.com/ViewFeature/Flow.git`
- バージョンを選択：`1.3.1`以降

**推奨**: ターゲットの**Build Settings → Other Swift Flags**に`-default-isolation MainActor`を追加してください。

### 動作環境

- iOS 18.0+ / macOS 15.0+ / watchOS 11.0+ / tvOS 18.0+
- Swift 6.2+
- Xcode 16.2+

## 貢献

コントリビューションを歓迎します！

プルリクエストを送信する前に、[貢献ガイド](CONTRIBUTING.md)を確認してください。質問やアイデアがある場合は、[ディスカッション](https://github.com/ViewFeature/Flow/discussions)を開始してください。

### コミュニティ

- 🐛 **[問題を報告](https://github.com/ViewFeature/Flow/issues)** - バグ報告と機能リクエスト
- 💬 **[ディスカッション](https://github.com/ViewFeature/Flow/discussions)** - 質問やアイデアの共有

## クレジット

Flowは以下のライブラリとコミュニティにインスパイアされています：

- [Redux](https://redux.js.org/) - 単方向データフローアーキテクチャ
- [ReSwift](https://github.com/ReSwift/ReSwift) - Swiftでの単方向データフロー実装
- [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) - Swiftの状態管理パターン

## メンテナー

- [Takeshi SHIMADA](https://github.com/takeshishimada)

## ライセンス

FlowはMITライセンスの下で配布されています。詳細は[LICENSE](LICENSE)ファイルを参照してください。
