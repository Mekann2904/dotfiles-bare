#!/bin/bash
# plugins/task_complete.sh
# タスクを完了としてマークするスクリプト
# ポップアップ内のタスクをクリックしたときに呼び出される

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"

# デバッグログ設定（必要時のみ）
DEBUG_LOG_FILE="${DEBUG_LOG:-}"
if [ -z "$DEBUG_LOG_FILE" ] && [ "${SKETCHYBAR_TASKS_DEBUG:-}" = "1" ]; then
  DEBUG_LOG_FILE="/tmp/sketchybar_tasks_debug.log"
fi
log_debug() {
  [ -n "$DEBUG_LOG_FILE" ] || return 0
  echo "$(date '+%Y-%m-%d %H:%M:%S') [TASK_COMPLETE] $*" >> "$DEBUG_LOG_FILE"
}

# 引数チェック
if [ $# -eq 0 ]; then
  log_debug "No task ID provided"
  exit 1
fi

TASK_ID="$1"
API_URL="https://my-app.yinyoo2904.workers.dev/api/v1/tasks/${TASK_ID}/execute"

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

log_debug "Completing task: $TASK_ID"

api_key=$(get_task_api_key)
if [ -z "$api_key" ]; then
  log_debug "Failed to get API key from Keychain"
  sketchybar --set tasks popup.drawing=off
  exit 1
fi

# タスク完了APIを呼び出す
response=$(curl -sS -X POST \
  --connect-timeout 2 \
  --max-time 6 \
  --retry 2 \
  --retry-delay 1 \
  --retry-connrefused \
  -H "Authorization: ApiKey $api_key" \
  -H "Content-Type: application/json" \
  "$API_URL" 2>/dev/null)

exit_code=$?

if [ $exit_code -eq 0 ] && [ -n "$response" ]; then
  log_debug "Task completed successfully: $TASK_ID"
  
  # キャッシュを削除して即時更新を強制
  CACHE_FILE="/tmp/sketchybar_tasks_cache"
  if [ -f "$CACHE_FILE" ]; then
    rm "$CACHE_FILE"
    log_debug "Cache cleared for immediate update"
  fi
  
  # タスクリストを即時更新
  env NAME=tasks "$CONFIG_DIR/plugins/tasks.sh" || true
  
  # ポップアップを閉じる
  sketchybar --set tasks popup.drawing=off
  
  log_debug "Tasks updated and popup closed"
else
  log_debug "Failed to complete task: $TASK_ID, exit_code=$exit_code"
  # エラー時もポップアップを閉じる
  sketchybar --set tasks popup.drawing=off
fi
