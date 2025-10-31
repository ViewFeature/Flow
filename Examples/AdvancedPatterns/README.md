# Flow Advanced Patterns

このディレクトリには、Flow を使用した実世界の複雑なユースケースの実装例が含まれています。

## 📚 パターン一覧

### 1. NetworkingWithRetry - リトライロジック付きネットワーク

**学習内容:**
- 指数バックオフリトライ
- 最大リトライ回数の制御
- カスタムエラー型によるエラーハンドリング
- タスクキャンセル
- リトライ中のローディング状態

**ファイル:**
- `NetworkingWithRetry/RetryNetworkFeature.swift`

**主要な技術:**
```swift
// 指数バックオフ delay の計算
private func calculateBackoffDelay(attempt: Int) -> Duration {
    let multiplier = Int(pow(2.0, Double(attempt)))
    return baseDelay * multiplier
}

// リトライ付きフェッチ
return .run { state in
    do {
        let items = try await apiClient.fetchItems()
        state.data = items
    } catch {
        if state.retryCount < maxRetries {
            state.retryCount += 1
            let delay = calculateBackoffDelay(attempt: state.retryCount)
            try await Task.sleep(for: delay)
            try await performFetch(state: state)  // 再帰的リトライ
        } else {
            throw RetryError.maxRetriesExceeded(attempts: maxRetries)
        }
    }
}
```

### 2. PaginatedList - 無限スクロール

**学習内容:**
- カーソルベースのページネーション
- Pull-to-refresh
- スクロールでの自動ロード
- 重複フェッチの防止
- 空状態のハンドリング
- エラーリカバリ

**ファイル:**
- `PaginatedList/PaginatedListFeature.swift`
- `PaginatedList/PaginatedListView.swift` (SwiftUI)

**主要な技術:**
```swift
case .loadMore:
    // 重複ロードを防止
    guard !state.isLoadingMore,
          !state.isInitialLoading,
          !state.isRefreshing,
          state.hasMore,
          let cursor = state.nextCursor
    else {
        return .none
    }

    state.isLoadingMore = true

    return .run { state in
        let response = try await apiClient.fetchPage(cursor: cursor)
        state.items.append(contentsOf: response.items)  // ← 既存アイテムに追加
        state.nextCursor = response.nextCursor
        state.hasMore = response.hasMore
    }
```

**SwiftUI 統合:**
```swift
LazyVStack {
    ForEach(store.state.items) { item in
        ItemRow(item: item)
            .onAppear {
                // 最後のアイテムが表示されたらロード
                if item.id == store.state.items.last?.id {
                    store.send(.loadMore)
                }
            }
    }
}
.refreshable {
    await store.send(.refresh).value  // Pull-to-refresh
}
```

### 3. MultiStepWizard - マルチステップフォーム

**学習内容:**
- ステートマシンによるステップ管理
- ステップごとのバリデーション
- 条件付きナビゲーション
- 進捗トラッキング
- ドラフト保存/復元
- 最終送信

**ファイル:**
- `MultiStepWizard/MultiStepWizardFeature.swift`

**主要な技術:**
```swift
// ステップの定義
enum Step: String, CaseIterable {
    case personalInfo = "Personal Info"
    case addressInfo = "Address"
    case paymentInfo = "Payment"
    case review = "Review"

    var next: Step? { ... }
    var previous: Step? { ... }
}

// ステップ間のナビゲーション
case .nextStep:
    return .run { state in
        let errors = validateStep(state.currentStep, state: state)

        if errors.isEmpty {
            state.completedSteps.insert(state.currentStep)

            if let nextStep = state.currentStep.next {
                state.currentStep = nextStep  // 次のステップへ
            }
        } else {
            setErrorsForStep(state.currentStep, errors: errors, state: state)
        }
    }
```

### 4. FormValidation - 複雑なバリデーション

**学習内容:**
- リアルタイムバリデーション
- 依存フィールドのバリデーション
- カスタムバリデーションルール
- エラーメッセージの管理
- バリデーション結果のキャッシュ

**(TODO: 実装予定)**

### 5. OfflineSync - オフライン同期

**学習内容:**
- オフライン/オンライン状態の検出
- ローカルキャッシュ
- 競合解決
- バックグラウンド同期
- 楽観的UI更新

**(TODO: 実装予定)**

### 6. RealTimeUpdates - WebSocket / リアルタイム

**学習内容:**
- WebSocket 接続管理
- リアルタイムイベントの処理
- 再接続ロジック
- メッセージキュー
- 接続状態の追跡

**(TODO: 実装予定)**

## 🎓 各パターンの使い方

### パターンの選択

| ユースケース | 推奨パターン |
|-------------|-------------|
| API呼び出しが時々失敗する | NetworkingWithRetry |
| 大量のアイテムを表示 | PaginatedList |
| 複数ステップのフォーム | MultiStepWizard |
| 複雑なフォームロジック | FormValidation |
| オフライン対応が必要 | OfflineSync |
| チャット、ライブフィード | RealTimeUpdates |

### パターンの組み合わせ

複数のパターンを組み合わせることも可能です：

```swift
// 例: ページネーション + リトライ
struct RobustPaginatedListFeature: Feature {
    let retryStrategy: RetryStrategy
    let paginationClient: PaginatedAPIClient

    func handle() -> ActionHandler<Action, State> {
        ActionHandler { action, state in
            case .loadMore:
                return .run { state in
                    // リトライロジックを使用してページフェッチ
                    try await withRetry(maxAttempts: 3) {
                        let response = try await paginationClient.fetchPage(cursor: state.nextCursor)
                        state.items.append(contentsOf: response.items)
                    }
                }
        }
    }
}
```

## 💡 ベストプラクティス

### 1. エラーハンドリング

各機能で専用のエラー型を定義してエラーハンドリング：

```swift
// アプリケーション固有のエラー型を定義
enum RetryError: Error, LocalizedError {
    case maxRetriesExceeded(attempts: Int)
    case networkFailure(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .maxRetriesExceeded(let attempts):
            return "Failed after \(attempts) retry attempts"
        case .networkFailure(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        }
    }
}

// エラーハンドリング
.catch { error, state in
    if let retryError = error as? RetryError {
        state.error = retryError
    } else {
        state.error = .networkFailure(underlying: error)
    }
}
```

### 2. ローディング状態

複数のローディング状態を明確に分離：

```swift
@Observable
final class State {
    var isInitialLoading = false    // 初回ロード
    var isRefreshing = false         // リフレッシュ
    var isLoadingMore = false        // 追加ロード
}
```

### 3. タスクキャンセル

ID を使用してタスクを管理：

```swift
return .run { state in
    try await operation()
}
.cancellable(id: "unique-task-id", cancelInFlight: true)
```

### 4. State の観測

全ての状態を State に保存し、UI で観測：

```swift
// ✅ Good
@Observable
final class State {
    var isLoading = false
    var error: RetryError?  // アプリケーション固有のエラー型
}

// ❌ Bad: Feature に状態を持つ
struct MyFeature: Feature {
    var isLoading = false  // ← @Observable ではない
}
```

## 🧪 テスト

各パターンには対応するテストがあります：

```bash
# 特定のパターンのテストを実行
swift test --filter RetryNetworkFeature
swift test --filter PaginatedListFeature
swift test --filter MultiStepWizardFeature
```

## 📖 詳細ドキュメント

各パターンのファイル内に詳細な DocC コメントがあります：

```swift
/// Advanced networking feature with exponential backoff retry logic.
///
/// Demonstrates:
/// - Retry with exponential backoff
/// - Maximum retry attempts
/// - Error handling with custom error types
/// ...
struct RetryNetworkFeature: Feature { ... }
```

## 🚀 次のステップ

1. **基本例から開始**: `Examples/DemoApp` の Counter, Todo, User を確認
2. **パターンを学ぶ**: このディレクトリの例を実行・修正
3. **自分のプロジェクトに適用**: パターンを実際のアプリに統合
4. **カスタマイズ**: 自分のユースケースに合わせて調整

## 📝 貢献

新しいパターンを追加したい場合：

1. 新しいディレクトリを作成 (例: `NewPattern/`)
2. Feature 実装を追加
3. SwiftUI View の例を追加（オプション）
4. この README に追加
5. テストを追加

## 参考資料

- [Flow Documentation](https://docs.flow.com)
- [SwiftUI Best Practices](https://developer.apple.com/documentation/swiftui)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
