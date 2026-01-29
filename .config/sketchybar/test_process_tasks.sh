#!/bin/bash
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"

# tasks.shの関数を読み込み
source "$CONFIG_DIR/plugins/tasks.sh"

# テストデータ（5タスク）
tasks_data='{"data":[
  {"title":"Task1","status":"todo","taskId":"1","timeLabel":"いつでも","target":"1","completed":"0"},
  {"title":"Task2","status":"todo","taskId":"2","timeLabel":"朝8時","target":"5","completed":"3"},
  {"title":"Task3","status":"done","taskId":"3","timeLabel":"昼12時","target":"1","completed":"1"},
  {"title":"Task4","status":"todo","taskId":"4","timeLabel":"いつでも","target":"1","completed":"0"},
  {"title":"Task5","status":"todo","taskId":"5","timeLabel":"夜20時","target":"3","completed":"1"}
]}'

echo "=== process_tasks 関数パフォーマンステスト ==="
echo ""

# 実行時間計測
start=$(python3 -c "import time; print(int(time.time()*1e9))")
result=$(process_tasks "$tasks_data")
end=$(python3 -c "import time; print(int(time.time()*1e9))")
duration=$(( (end - start) / 1000000 ))

echo "結果: $result"
echo "実行時間: ${duration}ms"
echo ""

if [ "$duration" -lt 100 ]; then
  echo "✅ 最適化済み: ${duration}ms（期待値: <100ms）"
else
  echo "⚠️  遅延: ${duration}ms（期待値: <100ms）"
fi
