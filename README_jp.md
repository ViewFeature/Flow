# Flow

[![Swift 6.2+](https://img.shields.io/badge/Swift-6.2+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20|%20macOS%20|%20watchOS%20|%20tvOS-blue.svg)](https://github.com/ViewFeature/Flow)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

SwiftUI向けの型安全な状態管理ライブラリです。単方向データフローアーキテクチャを採用し、Swift 6のApproachable Concurrencyに対応しています。

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

## 主な特徴

### グローバルストア不使用

各ビューが`@State`で自身の状態を保持します。

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

- 状態のスコープが明確（ビューと同じライフサイクル）
- グローバル状態の管理が不要

### 結果を返すアクション

アクションは`ActionTask`を通じて結果を返せます。結果の型（`ActionResult`）は各Featureで自由に定義できます。

この例では、子ビューが選択結果を親に返し、親が画面遷移を処理します：

```swift
struct ChildSelectFeature: Feature {
    @Observable
    final class State {
        var selectedId = ""
    }

    enum Action: Sendable {
        case select
    }

    enum ActionResult: Sendable {
        case selected(id: String)
    }

    func handle() -> ActionHandler<Action, State, ActionResult> {
        ActionHandler { action, state in
            switch action {
            case .select:
                return .run { state in
                    let id = state.selectedId
                    return .selected(id: id)
                }
            }
        }
    }
}

struct ChildView: View {
    @State private var store = Store(
        initialState: .init(),
        feature: ChildSelectFeature()
    )
    let onSelect: (String) async -> Void

    var body: some View {
        Button("選択") {
            Task {
                let result = await store.send(.select).value
                if case .success(.selected(let id)) = result {
                    await onSelect(id)
                }
            }
        }
    }
}

struct ParentView: View {
    @Environment(\.navigator) private var navigator

    var body: some View {
        ChildView { selectedId in
            await navigator.navigate(to: .detail(id: selectedId))
        }
    }
}
```

この実装により：
- `ChildFeature`が`ActionResult`を通じて選択結果を親に返す
- `ParentView`が`onSelect`コールバックで結果を受け取る
- 親が画面遷移などの副作用を制御
- すべてがビューツリー内で完結し、依存関係が追跡しやすい

### @Observable準拠

`@ObservableObject`や`@Published`ではなく、**SwiftUI標準の@Observable**を使用します。

```swift
@Observable
final class State {
    var count = 0  // @Publishedは不要
}
```

- Combine依存が不要
- コード量が削減される
- SwiftUIの標準APIとの統合

### Approachable Concurrency

Swift 6の並行性チェックに対応しています。`defaultIsolation(MainActor.self)`を前提とした設計です。

```swift
.defaultIsolation(MainActor.self)
```

すべての処理がMainActorで実行され、**データ競合がコンパイル時に検出**されます。

```swift
func handle() -> ActionHandler<Action, State, Void> {
    ActionHandler { action, state in
        switch action {
        case .increment:
            state.count += 1  // ✅ 同期処理も安全
            return .none

        case .loadData:
            return .run { state in
                let data = try await api.fetch()
                state.data = data  // ✅ 非同期処理内でも安全に状態変更
            }
        }
    }
}
```

- スレッドセーフが保証される
- `async/await`をネイティブサポート
- `.run`ブロック内でも直接状態を変更可能
- ランタイムエラーではなくコンパイルエラーで検出

### 観測可能なアクション

Flowは**ミドルウェア**を使用してアクションを観測できます。これにより、ロギング、分析、デバッグなどの横断的関心事を実装できます。

```swift
struct AnalyticsMiddleware: BeforeActionMiddleware {
    let id = "Analytics"
    let analytics: AnalyticsService

    func beforeAction<Action, State>(_ action: Action, state: State) async {
        analytics.track(String(describing: action))
    }
}

func handle() -> ActionHandler<Action, State, Void> {
    ActionHandler { action, state in
        // ...
    }
    .use(LoggingMiddleware(category: "Counter"))
    .use(AnalyticsMiddleware(analytics: .shared))
}
```

- すべてのアクションを一箇所で観測
- ロギング、分析、デバッグに利用可能

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
    .package(url: "https://github.com/ViewFeature/Flow.git", from: "1.2.0")
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
- バージョンを選択：`1.2.0`以降

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
