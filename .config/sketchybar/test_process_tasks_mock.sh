#!/bin/bash
# sketchybar コマンドをモック化して process_tasks 関数をテスト

# sketchybar モック
sketchybar() {
  # 引数を表示して終了（実際には何もしない）
  return 0
}

# キャッシュファイルを一時的なものに変更
CACHE_FILE="/tmp/test_tasks_cache_$$.txt"

# tasks.shの関数を読み込み（先頭部分）
process_tasks() {
  local tasks_data="$1"
  local incomplete_count=0
  local task_count=0

  incomplete_count=$(echo "$tasks_data" | jq -r '.data[] | select(.status == "todo") | .title' | wc -l | tr -d ' ')
  task_count=$(echo "$tasks_data" | jq -r '.data | length')

  local csv_data
  csv_data=$(echo "$tasks_data" | jq -r '
    .data[] |
    select(.title != null) |
    [
      (.title // ""),
      (.status // ""),
      (.taskId // ""),
      (.timeLabel // ""),
      (.target // "1"),
      (.completed // "0")
    ] | @csv
  ' 2>/dev/null)

  local task_data=()
  local i=1

  while IFS= read -r line; do
    [ -z "$line" ] && continue

    local title status task_id time_label target completed
    IFS=',' read -ra line_arr <<<"$line"

    title="${line_arr[0]#\"}"
    title="${title%\"}"
    status="${line_arr[1]#\"}"
    status="${status%\"}"
    task_id="${line_arr[2]#\"}"
    task_id="${task_id%\"}"
    time_label="${line_arr[3]#\"}"
    time_label="${time_label%\"}"
    target="${line_arr[4]#\"}"
    target="${target%\"}"
    completed="${line_arr[5]#\"}"
    completed="${completed%\"}"

    local display_label="$title"

    if [ "$time_label" != "いつでも" ] && [ "$time_label" != "null" ] && [ -n "$time_label" ]; then
      display_label="$display_label ($time_label)"
    fi

    if [ "$target" != "1" ] && [ "$target" != "null" ] && [ -n "$target" ]; then
      display_label="$display_label [$completed/$target]"
    fi

    task_data["$i"]="$status|$task_id|$display_label"
    i=$((i + 1))
  done <<<"$csv_data"

  local cmd=(sketchybar)
  local j
  for j in $(seq 1 10); do
    if [ -n "${task_data[$j]+isset}" ]; then
      IFS='|' read -r t_status t_id t_display <<<"${task_data[$j]}"

      if [ "$t_status" = "todo" ]; then
        cmd+=(--set "task.$j" icon="󰄱" label="$t_display" label.color=0xffffffff \
              click_script="/path/to/task_complete.sh $t_id" drawing=on)
      else
        cmd+=(--set "task.$j" icon="󰄲" label="$t_display" label.color=0x99ffffff \
              click_script="sketchybar --set tasks popup.drawing=off" drawing=on)
      fi
    else
      cmd+=(--set "task.$j" drawing=off)
    fi
  done

  "${cmd[@]}" >/dev/null 2>&1
  echo "$incomplete_count"
}

# テストデータ（5タスク）
tasks_data='{"data":[
  {"title":"Task1","status":"todo","taskId":"1","timeLabel":"いつでも","target":"1","completed":"0"},
  {"title":"Task2","status":"todo","taskId":"2","timeLabel":"朝8時","target":"5","completed":"3"},
  {"title":"Task3","status":"done","taskId":"3","timeLabel":"昼12時","target":"1","completed":"1"},
  {"title":"Task4","status":"todo","taskId":"4","timeLabel":"いつでも","target":"1","completed":"0"},
  {"title":"Task5","status":"todo","taskId":"5","timeLabel":"夜20時","target":"3","completed":"1"}
]}'

echo "=== process_tasks 関数パフォーマンステスト ==="
echo "テストデータ: 5タスク"
echo ""

# 実行時間計測
start=$(python3 -c "import time; print(int(time.time()*1e9))")
result=$(process_tasks "$tasks_data")
end=$(python3 -c "import time; print(int(time.time()*1e9))")
duration=$(( (end - start) / 1000000 ))

echo "結果: incomplete_count = $result"
echo "実行時間: ${duration}ms"
echo ""

if [ "$duration" -lt 100 ]; then
  echo "✅ 最適化済み: ${duration}ms（期待値: <100ms）"
else
  echo "⚠️  遅延: ${duration}ms（期待値: <100ms）"
fi

# クリーンアップ
rm -f "$CACHE_FILE"
