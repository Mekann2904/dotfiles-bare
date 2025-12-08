#!/usr/bin/env bash
# test_performance.sh
# ワークスペース更新スクリプト（旧/新）の実行時間を簡易比較する。
# 体感差を数値化して改善効果を確認するために存在する。
# 関連ファイル: plugins/update_single_workspace.sh, plugins/update_workspace_icons.sh, sketchybarrc, plugins/workspace_events.sh
# パフォーマンステストスクリプト
# 新旧のワークスペース更新スクリプトの速度を比較します

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"

echo "=== ワークスペース更新スクリプト パフォーマンステスト ==="
echo ""

# テスト設定
TEST_WORKSPACE=1
NUM_ITERATIONS=5

# 時間計測関数
time_command() {
    local label="$1"
    local command="$2"
    
    echo "🔍 $label をテスト中..."
    
    local total_time=0
    for i in $(seq 1 $NUM_ITERATIONS); do
        local start_time=$(date +%s.%3N)
        eval "$command" > /dev/null 2>&1
        local end_time=$(date +%s.%3N)
        local duration=$(echo "$end_time - $start_time" | bc -l)
        total_time=$(echo "$total_time + $duration" | bc -l)
        echo "  試行 $i: ${duration}s"
    done
    
    local avg_time=$(echo "scale=3; $total_time / $NUM_ITERATIONS" | bc -l)
    echo "✅ $label 平均時間: ${avg_time}s"
    echo ""
}

# 環境変数を設定してデバッグログを有効化
export DEBUG_LOG=/tmp/sketchybar_perf_test.log
export PERF_LOG=/tmp/sketchybar_perf_measure.log

# 既存のログファイルをクリア
rm -f "$DEBUG_LOG" "$PERF_LOG" 2>/dev/null

echo "📊 テスト設定:"
echo "   ワークスペース: $TEST_WORKSPACE"
echo "   試行回数: $NUM_ITERATIONS"
echo "   デバッグログ: $DEBUG_LOG"
echo "   パフォーマンスログ: $PERF_LOG"
echo ""

# 古いスクリプトのテスト（ロック機構あり）
if [ -x "$CONFIG_DIR/plugins/update_workspace_icons.sh" ]; then
    time_command "古いスクリプト (update_workspace_icons.sh)" \
        "$CONFIG_DIR/plugins/update_workspace_icons.sh $TEST_WORKSPACE"
else
    echo "⚠️  古いスクリプトが見つかりません: update_workspace_icons.sh"
fi

# 新しいスクリプトのテスト（高速版）
if [ -x "$CONFIG_DIR/plugins/update_single_workspace.sh" ]; then
    time_command "新しいスクリプト (update_single_workspace.sh)" \
        "$CONFIG_DIR/plugins/update_single_workspace.sh $TEST_WORKSPACE"
else
    echo "❌ 新しいスクリプトが見つかりません: update_single_workspace.sh"
fi

# 全ワークスペース更新のテスト
echo "🔍 全ワークスペース更新をテスト中..."
time_command "全ワークスペース更新 (新しいスクリプト)" \
    "$CONFIG_DIR/plugins/update_single_workspace.sh"

echo ""
echo "=== テスト結果サマリー ==="
echo "📈 改善点:"
echo "   • ロック機構の排除による並列処理の可能性"
echo "   • 対象ワークスペース限定による不要なスキャン削減"
echo "   • SketchyBarコマンドのバッチ化による効率向上"
echo "   • 軽量な実装によるメモリ使用量削減"
echo ""
echo "📋 次のステップ:"
echo "   1. SketchyBarを再起動して変更を適用"
echo "   2. アプリ起動/終了時の更新遅延を確認"
echo "   3. 問題があればデバッグログを確認: $DEBUG_LOG"
echo ""
echo "✅ パフォーマンステスト完了"
