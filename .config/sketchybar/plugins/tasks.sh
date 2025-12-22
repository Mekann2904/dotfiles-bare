#!/bin/bash
# plugins/tasks.sh
# タスクAPIから今日のタスクを取得し、SketchyBarに表示する。
# APIエラー時は非表示にしてバーの安定性を保つために存在する。
# 関連ファイル: sketchybarrc, plugins/clock.sh, plugins/ram_min.sh

# デバッグログ設定
DEBUG_LOG_FILE="/tmp/sketchybar_tasks_debug.log"
log_debug() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [TASKS] $*" >> "$DEBUG_LOG_FILE"
}

# API設定
API_URL="https://my-app.yinyoo2904.workers.dev/api/v1/tasks/today"
API_KEY="r3iMVBxVM-czqeapGrvYF9DdYHDoiD7XTiwteJQ36Oc"

# キャッシュ設定
CACHE_FILE="/tmp/sketchybar_tasks_cache"
CACHE_DURATION=3600  # 1時間キャッシュ

# APIからタスクを取得する関数
fetch_tasks() {
  local response
  local exit_code
  
  log_debug "Fetching tasks from API"
  
  # API呼び出し
  response=$(curl -sS \
    -H "Authorization: ApiKey $API_KEY" \
    "$API_URL" 2>/dev/null)
  exit_code=$?
  
  if [ $exit_code -ne 0 ]; then
    log_debug "API call failed with exit code: $exit_code"
    return 1
  fi
  
  # レスポンスの検証
  if [ -z "$response" ]; then
    log_debug "Empty API response"
    return 1
  fi
  
  # jqでパースできるか確認
  if ! echo "$response" | jq -e '.data' >/dev/null 2>&1; then
    log_debug "Invalid JSON response"
    return 1
  fi
  
  echo "$response"
  return 0
}

# キャッシュからタスクを取得または更新
get_cached_tasks() {
  local current_time=$(date +%s)
  local cache_time
  local cached_data
  
  # キャッシュファイルが存在する場合
  if [ -f "$CACHE_FILE" ]; then
    cache_time=$(head -n1 "$CACHE_FILE")
    cached_data=$(tail -n+2 "$CACHE_FILE")
    
    # キャッシュが有効期限内かチェック
    if [ $((current_time - cache_time)) -lt $CACHE_DURATION ] && [ -n "$cached_data" ]; then
      log_debug "Using cached tasks data"
      echo "$cached_data"
      return 0
    fi
  fi
  
  # 新しいデータを取得
  local new_data
  new_data=$(fetch_tasks)
  
  if [ $? -eq 0 ] && [ -n "$new_data" ]; then
    # キャッシュを更新
    echo "$current_time" > "$CACHE_FILE"
    echo "$new_data" >> "$CACHE_FILE"
    log_debug "Cache updated with new data"
    echo "$new_data"
    return 0
  else
    log_debug "Failed to fetch new data, using stale cache if available"
    # 新しいデータの取得に失敗した場合、古いキャッシュがあれば使用
    if [ -n "$cached_data" ]; then
      echo "$cached_data"
      return 0
    fi
    return 1
  fi
}

# 現在注力すべきタスクを選ぶ（時間指定優先 → 最初のTODO）
pick_focus_task() {
  local tasks_data="$1"
  local current_hour=$(date +%H)
  local task_count=$(echo "$tasks_data" | jq -r '.data | length')
  local focus_task=""
  local first_todo=""

  for i in $(seq 0 $((task_count - 1))); do
    local task_title=$(echo "$tasks_data" | jq -r ".data[$i].title")
    local task_status=$(echo "$tasks_data" | jq -r ".data[$i].status")
    local time_label=$(echo "$tasks_data" | jq -r ".data[$i].timeLabel")

    # 最初のTODOを覚えておく（時間指定なしでも表示に使う）
    if [ "$task_status" = "todo" ] && [ -z "$first_todo" ]; then
      first_todo="$task_title"
    fi

    # 時間指定が現在の時間と一致するTODOがあれば最優先で採用
    if [ "$task_status" = "todo" ] && [ "$time_label" != "いつでも" ] && [ "$time_label" != "null" ] && [ -n "$time_label" ]; then
      local task_hour=""
      case "$time_label" in
        *朝*7*時*) task_hour=7 ;;
        *朝*8*時*) task_hour=8 ;;
        *朝*9*時*) task_hour=9 ;;
        *昼*12*時*) task_hour=12 ;;
        *昼*13*時*) task_hour=13 ;;
        *昼*14*時*) task_hour=14 ;;
        *夕*18*時*) task_hour=18 ;;
        *夕*19*時*) task_hour=19 ;;
        *夜*20*時*) task_hour=20 ;;
        *夜*21*時*) task_hour=21 ;;
        *夜*22*時*) task_hour=22 ;;
        *) task_hour="" ;;
      esac

      if [ -n "$task_hour" ] && [ "$task_hour" -eq "$current_hour" ]; then
        focus_task="$task_title"
        break
      fi
    fi
  done

  if [ -z "$focus_task" ]; then
    focus_task="$first_todo"
  fi

  echo "$focus_task"
}

# タスクデータを処理
process_tasks() {
  local tasks_data="$1"
  local incomplete_count=0
  local task_count=0
  
  # タスクデータから不完全なタスクをカウント
  incomplete_count=$(echo "$tasks_data" | jq -r '.data[] | select(.status == "todo") | .title' | wc -l | tr -d ' ')
  task_count=$(echo "$tasks_data" | jq -r '.data | length')
  
  # ポップアップアイテムを更新（エラーを無視）
  local i=1
  while [ $i -le 10 ]; do
    if [ $i -le $task_count ]; then
      local task_title=$(echo "$tasks_data" | jq -r ".data[$((i-1))].title")
      local task_status=$(echo "$tasks_data" | jq -r ".data[$((i-1))].status")
      local task_id=$(echo "$tasks_data" | jq -r ".data[$((i-1))].taskId")
      local time_label=$(echo "$tasks_data" | jq -r ".data[$((i-1))].timeLabel")
      local target=$(echo "$tasks_data" | jq -r ".data[$((i-1))].target")
      local completed=$(echo "$tasks_data" | jq -r ".data[$((i-1))].completed")
      
      # タスクラベルを構築
      local display_label="$task_title"
      
      # 時間指定がある場合は追加（"いつでも"以外）
      if [ "$time_label" != "いつでも" ] && [ "$time_label" != "null" ] && [ -n "$time_label" ]; then
        display_label="$display_label ($time_label)"
      fi
      
      # 複数回行うものは進捗を表示
      if [ "$target" != "1" ] && [ "$target" != "null" ] && [ -n "$target" ]; then
        display_label="$display_label [$completed/$target]"
      fi
      
      if [ "$task_status" = "todo" ]; then
        sketchybar --set "task.$i" \
          icon="󰄱" \
          label="$display_label" \
          label.color=0xffffffff \
          click_script="$CONFIG_DIR/plugins/task_complete.sh $task_id" \
          drawing=on 2>/dev/null || true
      else
        sketchybar --set "task.$i" \
          icon="󰄲" \
          label="$display_label" \
          label.color=0x99ffffff \
          click_script="sketchybar --set tasks popup.drawing=off" \
          drawing=on 2>/dev/null || true
      fi
    else
      # 余分なタスクアイテムを非表示
      sketchybar --set "task.$i" drawing=off 2>/dev/null || true
    fi
    i=$((i + 1))
  done
  
  echo "$incomplete_count"
}

# メイン処理
main() {
  local tasks_data
  local processed_data
  local incomplete_count
  local task_list
  
  log_debug "Starting tasks update"
  
  # タスクデータを取得
  tasks_data=$(get_cached_tasks)
  
  if [ $? -ne 0 ] || [ -z "$tasks_data" ]; then
    log_debug "No tasks data available, hide item"
    sketchybar --set "$NAME" drawing=off label="" icon=""
    exit 0
  fi
  
  # タスクデータを処理
  incomplete_count=$(process_tasks "$tasks_data")
  
  log_debug "Processed tasks: incomplete=$incomplete_count"
  
  # 現在時刻のタスクを取得
  current_task=$(pick_focus_task "$tasks_data")
  
  if [ "$incomplete_count" -eq 0 ]; then
    log_debug "No incomplete tasks, hide item"
    sketchybar --set "$NAME" drawing=off label="" icon=""
    exit 0
  fi

  if [ -n "$current_task" ]; then
    display_label="$incomplete_count $current_task"
    log_debug "Current time task found: $current_task, showing with count"
  else
    display_label="$incomplete_count"
    log_debug "No current time task, showing count only: $incomplete_count"
  fi
  
  sketchybar --set "$NAME" \
    icon="󰓾" \
    label="$display_label" \
    drawing=on
  
  log_debug "Tasks updated: icon=󰓾, label=$display_label"
}

# スクリプト実行
main
