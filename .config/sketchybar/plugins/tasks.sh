#!/bin/bash
# plugins/tasks.sh
# タスクAPIから今日のタスクを取得し、SketchyBarに表示する。
# APIエラー時は非表示にしてバーの安定性を保つために存在する。
# 関連ファイル: sketchybarrc, plugins/clock.sh, plugins/ram_min.sh

# デバッグログ設定（必要時のみ）
DEBUG_LOG_FILE="${DEBUG_LOG:-}"
if [ -z "$DEBUG_LOG_FILE" ] && [ "${SKETCHYBAR_TASKS_DEBUG:-}" = "1" ]; then
  DEBUG_LOG_FILE="/tmp/sketchybar_tasks_debug.log"
fi
log_debug() {
  [ -n "$DEBUG_LOG_FILE" ] || return 0
  echo "$(date '+%Y-%m-%d %H:%M:%S') [TASKS] $*" >> "$DEBUG_LOG_FILE"
}

# API設定
API_URL="https://my-app.yinyoo2904.workers.dev/api/v1/tasks/today"

# curl 設定
CURL_CONNECT_TIMEOUT="${TASKS_CONNECT_TIMEOUT:-2}"
CURL_MAX_TIME="${TASKS_MAX_TIME:-6}"
CURL_RETRY="${TASKS_RETRY:-2}"
CURL_RETRY_DELAY="${TASKS_RETRY_DELAY:-1}"

# キャッシュ設定
CACHE_FILE="/tmp/sketchybar_tasks_cache"
CACHE_DURATION=3600  # 1時間キャッシュ

# KeychainからAPIキーを取得する関数
get_task_api_key() {
  local service="sketchybar-tasks"
  local account="api-key"
  local api_key

  if command -v security >/dev/null 2>&1; then
    api_key=$(security find-generic-password -s "$service" -a "$account" -w 2>/dev/null)
    if [ -n "$api_key" ]; then
      echo "$api_key"
      return 0
    else
      log_debug "API key not found in Keychain (service: $service, account: $account)"
      return 1
    fi
  else
    log_debug "security command not available"
    return 1
  fi
}

# APIからタスクを取得する関数
fetch_tasks() {
  local response
  local exit_code
  
  log_debug "Fetching tasks from API"
  
  # APIキーの確認（Keychainから取得）
  local api_key
  api_key=$(get_task_api_key)
  
  if [ -z "$api_key" ]; then
    log_debug "Failed to get API key from Keychain"
    return 1
  fi
  
  # API呼び出し
  response=$(curl -sS \
    --connect-timeout "$CURL_CONNECT_TIMEOUT" \
    --max-time "$CURL_MAX_TIME" \
    --retry "$CURL_RETRY" \
    --retry-delay "$CURL_RETRY_DELAY" \
    --retry-connrefused \
    -H "Authorization: ApiKey $api_key" \
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

    if [ -z "$cache_time" ]; then
      log_debug "Cache file missing timestamp"
    elif [ -z "$cached_data" ]; then
      log_debug "Cache file missing payload"
    fi

    # キャッシュが有効期限内かチェック
    if [ -n "$cache_time" ] && [ $((current_time - cache_time)) -lt $CACHE_DURATION ] && [ -n "$cached_data" ]; then
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
    local tmp_cache="${CACHE_FILE}.$$"
    {
      echo "$current_time"
      echo "$new_data"
    } > "$tmp_cache"
    mv "$tmp_cache" "$CACHE_FILE"
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

# 時間ラベルから時刻を抽出
task_hour_from_label() {
  local time_label="$1"
  case "$time_label" in
    *朝*7*時*) echo 7 ;;
    *朝*8*時*) echo 8 ;;
    *朝*9*時*) echo 9 ;;
    *昼*12*時*) echo 12 ;;
    *昼*13*時*) echo 13 ;;
    *昼*14*時*) echo 14 ;;
    *夕*18*時*) echo 18 ;;
    *夕*19*時*) echo 19 ;;
    *夜*20*時*) echo 20 ;;
    *夜*21*時*) echo 21 ;;
    *夜*22*時*) echo 22 ;;
    *) echo "" ;;
  esac
}

# タスクデータを処理
process_tasks() {
  local tasks_lines="$1"
  local incomplete_count=0
  local focus_task=""
  local first_todo=""
  local current_hour
  local task_hour
  current_hour=$((10#$(date +%H)))

  local i=1
  local cmd=(sketchybar)

  if [ -z "$tasks_lines" ]; then
    while [ $i -le 10 ]; do
      cmd+=(--set "task.$i" drawing=off)
      i=$((i + 1))
    done
    "${cmd[@]}" 2>/dev/null || true
    printf '%s\037%s' "$incomplete_count" "$focus_task"
    return
  fi

  while IFS=$'\t' read -r task_title task_status task_id time_label target completed; do
    [ -n "$task_title" ] || continue

    if [ "$task_status" = "todo" ]; then
      incomplete_count=$((incomplete_count + 1))
      if [ -z "$first_todo" ]; then
        first_todo="$task_title"
      fi

      if [ -z "$focus_task" ] && [ -n "$time_label" ] && [ "$time_label" != "null" ] && [ "$time_label" != "いつでも" ]; then
        task_hour="$(task_hour_from_label "$time_label")"
        if [ -n "$task_hour" ] && [ "$task_hour" -eq "$current_hour" ]; then
          focus_task="$task_title"
        fi
      fi
    fi

    if [ "$i" -le 10 ]; then
      local display_label="$task_title"

      if [ -n "$time_label" ] && [ "$time_label" != "null" ] && [ "$time_label" != "いつでも" ]; then
        display_label="$display_label ($time_label)"
      fi

      if [ "$target" != "1" ] && [ "$target" != "null" ] && [ -n "$target" ]; then
        display_label="$display_label [$completed/$target]"
      fi

      if [ "$task_status" = "todo" ]; then
        cmd+=(--set "task.$i"
          icon="󰄱"
          label="$display_label"
          label.color=0xffffffff
          click_script="$CONFIG_DIR/plugins/task_complete.sh $task_id"
          drawing=on
        )
      else
        cmd+=(--set "task.$i"
          icon="󰄲"
          label="$display_label"
          label.color=0x99ffffff
          click_script="sketchybar --set tasks popup.drawing=off"
          drawing=on
        )
      fi
    fi
    i=$((i + 1))
  done <<<"$tasks_lines"

  while [ $i -le 10 ]; do
    cmd+=(--set "task.$i" drawing=off)
    i=$((i + 1))
  done

  "${cmd[@]}" 2>/dev/null || true

  if [ -z "$focus_task" ]; then
    focus_task="$first_todo"
  fi

  printf '%s\037%s' "$incomplete_count" "$focus_task"
}

# メイン処理
main() {
  local tasks_data
  local tasks_lines
  local incomplete_count
  local current_task

  if ! command -v jq >/dev/null 2>&1; then
    log_debug "jq not installed"
    sketchybar --set "$NAME" drawing=on label="jq未インストール" icon="!"
    exit 0
  fi

  log_debug "Starting tasks update"

  # タスクデータを取得
  tasks_data=$(get_cached_tasks)
  
  if [ $? -ne 0 ] || [ -z "$tasks_data" ]; then
    log_debug "No tasks data available, show placeholder"
    sketchybar --set "$NAME" drawing=on icon="󰓾" label="--"
    exit 0
  fi
  
  # タスクデータを一度でパース
  tasks_lines=$(echo "$tasks_data" | jq -r '.data[] | [.title, .status, .taskId, (.timeLabel // ""), (.target // ""), (.completed // "")] | @tsv' 2>/dev/null || true)

  # タスクデータを処理
  local result
  result=$(process_tasks "$tasks_lines")
  IFS=$'\037' read -r incomplete_count current_task <<<"$result"
  
  log_debug "Processed tasks: incomplete=$incomplete_count"
  
  if [ "$incomplete_count" -eq 0 ]; then
    log_debug "No incomplete tasks, show zero"
    sketchybar --set "$NAME" drawing=on icon="󰓾" label="0"
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
