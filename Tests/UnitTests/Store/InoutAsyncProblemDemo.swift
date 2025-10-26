import Foundation
import Testing

/// Demonstrates why inout + async is problematic
@MainActor
final class InoutAsyncProblemDemo {
  // MARK: - The Problem with inout + async

  /// ⏱️ CASE 1: Understanding suspension points
  @Test func suspensionPointBasics() async {
    var message = "Start"

    func asyncOperation(_ msg: inout String) async {
      msg = "Step 1"
      print("Before suspension: \(msg)")

      // 🔄 SUSPENSION POINT: 実行が中断される可能性
      try? await Task.sleep(nanoseconds: 1000)

      // ⚠️ ここに戻ってきたとき、msg は変更されているかも？
      print("After suspension: \(msg)")
      msg = "Step 2"
    }

    await asyncOperation(&message)
    #expect(message == "Step 2")
  }

  /// 💥 CASE 2: The race condition scenario (conceptual)
  @Test func conceptualRaceCondition() async {
    // このテストは「なぜ禁止されているか」を説明するための概念的なもの

    /*
     想定されるシナリオ（もし許可されていたら）:
    
     @MainActor
     class Store {
     private var state = State()
    
     func process() async {
     await asyncModify(&state)  // ❌ 実際は禁止されている
     }
    
     func asyncModify(_ s: inout State) async {
     s.count = 1
     // 👇 SUSPENSION POINT
     await Task.sleep(...)
     // 👆 この間に MainActor の他のタスクが実行される可能性
    
     // 問題:
     // 1. 他のタスクが state を読む → inout の排他性違反
     // 2. 他のタスクが state を変更 → データ競合
     // 3. 予測不可能な動作 → バグ
    
     s.count = 2  // どの state を変更している？
     }
    
     func anotherTask() {
     // もし asyncModify が suspension 中なら？
     print(state.count)  // ⚠️ 不定な値が読まれる可能性
     }
     }
     */

    #expect(true)  // Conceptual test
  }

  // MARK: - Synchronous inout is fine

  /// ✅ CASE 3: Synchronous functions with inout - OK!
  @Test func synchronousInoutOK() {
    var count = 0

    // ✅ 同期関数なら inout は問題なし
    func syncModify(_ value: inout Int) {
      value += 1
      value += 2
      value += 3
      // 中断なし = 排他的アクセスが保証される
    }

    syncModify(&count)
    #expect(count == 6)
  }

  // MARK: - Actor isolation makes it worse

  /// 🎭 CASE 4: Why actor-isolated + inout + async is especially bad
  @Test func actorIsolatedProblem() async {
    // Actor は re-entrant（再入可能）
    // つまり、await 中に別のタスクが同じ actor で実行できる

    @MainActor
    class Counter {
      var count = 0

      // これが許可されていたら...（実際は禁止）
      /*
       func badAsyncIncrement() async {
       await asyncModify(&count)  // ❌ 禁止
       }
      
       func asyncModify(_ value: inout Int) async {
       value += 1
       await Task.sleep(...)  // 👈 ここで他のタスクが実行可能
       // ↓ もし別のタスクが count を読んだら？
       value += 1
       }
       */

      // ✅ 正しい方法
      func goodAsyncIncrement() async {
        count += 1  // 直接変更
        try? await Task.sleep(nanoseconds: 1000)
        count += 1  // OK: actor が同期を保証
      }
    }

    let counter = Counter()
    await counter.goodAsyncIncrement()
    #expect(counter.count == 2)
  }

  // MARK: - The workaround: Local variables

  /// ✅ CASE 5: Safe pattern with local variables
  @Test func localVariableWorkaround() async {
    @MainActor
    class Store {
      var state = State()  // internal for testing

      struct State {
        var count = 0
      }

      // ❌ これは不可能
      /*
       func badPattern() async {
       await asyncModify(&state)  // Error!
       }
       */

      // ✅ これが正しいパターン
      func goodPattern() async {
        var localState = state  // 値型ならコピー
        await asyncModify(&localState)  // OK: actor-isolated ではない
        state = localState  // 結果を戻す
      }

      func asyncModify(_ stateParam: inout State) async {
        stateParam.count += 1
        try? await Task.sleep(nanoseconds: 1000)
        stateParam.count += 1
      }
    }

    let store = Store()
    await store.goodPattern()
    #expect(store.state.count == 2)
  }

  /// ✅ CASE 6: Reference type pattern (Flow's approach)
  @Test func referenceTypeWorkaround() async {
    @MainActor
    class Store {
      var state = State()  // internal for testing

      class State {
        var count = 0
      }

      // ✅ Flow のパターン（参照型）
      func goodPattern() async {
        var localState = state  // 参照のコピー（同じオブジェクト）
        await asyncModify(&localState)  // OK: localState は actor-isolated ではない
        // state も自動的に更新されている（参照型なので）
      }

      func asyncModify(_ stateParam: inout State) async {
        stateParam.count += 1
        try? await Task.sleep(nanoseconds: 1000)
        stateParam.count += 1
      }
    }

    let store = Store()
    await store.goodPattern()
    #expect(store.state.count == 2)
  }

  // MARK: - Visual timeline

  /// 📊 CASE 7: Timeline visualization
  @Test func timelineVisualization() async {
    print(
      """

      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      もし actor-isolated property を inout + async に渡せたら...
      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      Task A (on MainActor):
      ├─ await asyncModify(&_state)
      │  ├─ _state.count = 1
      │  ├─ await Task.sleep(...)  👈 SUSPENSION!
      │  │
      │  │  ⚡️ この間に Task B が実行される可能性
      │  │
      │  │  Task B (on MainActor):
      │  │  ├─ print(_state.count)  ⚠️ inout で排他的にアクセス中なのに！
      │  │  └─ 違反！予測不可能な動作！
      │  │
      │  └─ _state.count = 2  // Task B が見た値は？
      └─ Done

      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      実際の Swift: この状況を **コンパイル時に防ぐ**
      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      """)

    #expect(true)
  }

  // MARK: - Key takeaways

  /// 📝 CASE 8: Summary
  @Test func summary() {
    print(
      """

      ╔═══════════════════════════════════════════════════════════════╗
      ║  inout の排他的アクセス - まとめ                                ║
      ╚═══════════════════════════════════════════════════════════════╝

      1️⃣  **排他的アクセスとは**
         → 同じメモリに同時に複数アクセスできない保証

      2️⃣  **なぜ inout が必要とするか**
         → inout は値を「その場で変更」する
         → 変更中に他が読むと不整合が起こる

      3️⃣  **同期関数では問題なし**
         → 関数が完了するまで中断なし
         → 排他性が自動的に保証される

      4️⃣  **async 関数で問題**
         → suspension point で実行が中断
         → その間に他のタスクがアクセス可能
         → 排他性が破られる

      5️⃣  **actor でさらに問題**
         → Actor は re-entrant（再入可能）
         → await 中に同じ actor で別タスク実行
         → 非常に簡単にバグを作れてしまう

      6️⃣  **解決策**
         → ローカル変数を使う（actor-isolated ではない）
         → 参照型なら同じオブジェクトを指す
         → 安全に inout を使える

      """)

    #expect(true)
  }
}
