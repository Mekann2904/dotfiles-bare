#!/usr/bin/env bash
# plugins/update_workspace_icons.sh
# AeroSpaceのウィンドウ一覧を使って各ワークスペースにネイティブアイコンをまとめて描画する。
# SketchyBarのワークスペース表示が常に最新になるようにこの集約スクリプトが存在する。
# 関連ファイル: plugins/aerospace.sh, sketchybarrc, plugins/icon_map_fn.sh, plugins/space_windows.sh

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"

# デバッグログ設定（DEBUG_LOGが設定されている場合のみ有効）
if [ -n "$DEBUG_LOG" ]; then
  DEBUG_LOG="${DEBUG_LOG:-/tmp/sketchybar_workspace_debug.log}"
  log_debug() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [DEBUG] $*" >> "$DEBUG_LOG"
  }
else
  log_debug() { :; }  # 何もしない
fi

# Tunables（WORKSPACE_RANGE_MAXを9にすれば即座に1-9へ戻せる）
DEFAULT_MIN_WORKSPACE=1
DEFAULT_MAX_WORKSPACE=7
MIN_WORKSPACE=${MIN_WORKSPACE:-$DEFAULT_MIN_WORKSPACE}
MAX_WORKSPACE=${WORKSPACE_RANGE_MAX:-${MAX_WORKSPACE:-$DEFAULT_MAX_WORKSPACE}}
VISIBLE_ICON_SLOTS=${VISIBLE_ICON_SLOTS:-4}
ICON_WIDTH=${ICON_WIDTH:-16}
ICON_HEIGHT=${ICON_HEIGHT:-16}
ICON_ITEM_WIDTH=${ICON_ITEM_WIDTH:-24}
ICON_IMAGE_SCALE=${ICON_IMAGE_SCALE:-0.8}

# Lock (portable): mkdir is atomic on POSIX
LOCK_DIR="${LOCK_DIR:-/tmp/skbar_wsicons.lock}"
LOCK_RETRY_INTERVAL="${LOCK_RETRY_INTERVAL:-0.05}"
LOCK_MAX_RETRY="${LOCK_MAX_RETRY:-40}"

cleanup_lock() {
  [ -d "$LOCK_DIR" ] && rmdir "$LOCK_DIR" >/dev/null 2>&1
  log_debug "Lock cleaned up"
}

acquire_lock() {
  local attempt=0
  log_debug "Attempting to acquire lock (max retries: $LOCK_MAX_RETRY)"
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge "$LOCK_MAX_RETRY" ]; then
      log_debug "Failed to acquire lock after $attempt attempts"
      return 1
    fi
    sleep "$LOCK_RETRY_INTERVAL"
  done
  log_debug "Lock acquired successfully after $attempt attempts"
  return 0
}

if ! acquire_lock; then
  log_debug "Exiting due to lock acquisition failure"
  exit 0
fi
trap cleanup_lock EXIT INT TERM

trim() {
  local v="$1"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  printf '%s' "$v"
}

normalize_ws() {
  local s; s="$(trim "$1")"
  [ -n "$s" ] || return 1
  local d="${s%%[!0-9]*}"
  [ -n "$d" ] || return 1
  printf '%s\n' "$d"
}

is_supported_ws() {
  case "$1" in ''|*[!0-9]*) return 1;; esac
  [ "$1" -ge "$MIN_WORKSPACE" ] && [ "$1" -le "$MAX_WORKSPACE" ]
}

collect_windows() {
   # Args: optional workspace ids
   local args=()
   if [ "$#" -gt 0 ]; then
     local raw w
     for raw in "$@"; do
       w="$(normalize_ws "$raw")" || continue
       is_supported_ws "$w" || continue
       args+=(--workspace "$w")
     done
   fi
   [ "${#args[@]}" -gt 0 ] || args=(--all)

   # キャッシュファイル（即時更新のため無効化）
   # local cache_file="/tmp/sketchybar_aerospace_cache_$$"
   # local cache_timestamp_file="${cache_file}_ts"
   # local current_time=$(date +%s)
   # local cache_age=0

   # # キャッシュが存在し、1秒以内なら使用
   # if [ -f "$cache_file" ] && [ -f "$cache_timestamp_file" ]; then
   #   local cache_time=$(cat "$cache_timestamp_file" 2>/dev/null || echo 0)
   #   cache_age=$((current_time - cache_time))
   #   if [ "$cache_age" -le 1 ]; then
   #     log_debug "Using cached aerospace data (age: ${cache_age}s)"
   #     cat "$cache_file"
   #     return 0
   #   fi
   # fi

   # aerospaceコマンドの存在確認とエラーハンドリング
   if ! command -v aerospace >/dev/null 2>&1; then
     log_debug "aerospace command not found"
     return 1
   fi

   local output
   if ! output=$(aerospace list-windows "${args[@]}" --format '%{workspace}|%{app-name}' 2>/dev/null); then
     log_debug "aerospace command failed with args: ${args[*]}"
     return 1
   fi

   # キャッシュに保存
   echo "$output" > "$cache_file"
   echo "$current_time" > "$cache_timestamp_file"
   log_debug "Cached new aerospace data"

   echo "$output"
}

apps_for_ws() {
  # Params: $1 = ws id, stdin "ws|app"
  # Trim both fields, then order-preserving dedup
  awk -F'|' -v id="$1" '
    {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1);
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2);
      if ($1 == id) print $2;
    }
  ' | awk '!seen[$0]++'
}

escape_app_for_sketchybar() {
  # escape " and \ for safe double-quoted assignment
  printf '%s' "$1" | sed -e 's/[\\"]/\\&/g'
}

build_and_apply_updates() {
  # Params: $1=ws, stdin = unique apps (one per line)
  local ws="$1"
  local uniq apps total extra
  uniq="$(cat)"
  total=$(printf '%s\n' "$uniq" | grep -c . || true)
  if [ "$total" -gt "$VISIBLE_ICON_SLOTS" ]; then
    extra=$((total - VISIBLE_ICON_SLOTS))
  else
    extra=0
  fi
  apps="$(printf '%s\n' "$uniq" | sed -n "1,${VISIBLE_ICON_SLOTS}p")"

  local cmd=(sketchybar
    --set "space.$ws" drawing=on icon="$ws" icon.drawing=on icon.background.drawing=off icon.background.image="" label="" label.drawing=off
  )

  local slot=1
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    local app esc item="space.$ws.icon$slot"
    app="$(trim "$line")"
    esc="$(escape_app_for_sketchybar "$app")"
    if [ -n "$app" ]; then
      cmd+=( --set "$item"
        drawing=on
        width="$ICON_ITEM_WIDTH"
        icon=" "
        icon.drawing=on
        icon.background.image="app.$esc"
        icon.background.drawing=on
        icon.background.image.scale="$ICON_IMAGE_SCALE"
        icon.background.corner_radius=3
        icon.background.height="$ICON_HEIGHT"
        icon.background.y_offset=0
        icon.padding_left=2
        icon.padding_right=2
        icon.width="$ICON_WIDTH"
        label=""
        label.drawing=off
      )
    else
      cmd+=( --set "$item"
        drawing=off
        width="$ICON_ITEM_WIDTH"
        icon=""
        icon.drawing=off
        icon.background.image=""
        icon.background.drawing=off
        icon.background.height="$ICON_HEIGHT"
        icon.background.y_offset=0
        label=""
        label.drawing=off
      )
    fi
    slot=$((slot+1))
  done <<EOF
$apps
EOF

  while [ "$slot" -le "$VISIBLE_ICON_SLOTS" ]; do
    local item="space.$ws.icon$slot"
    cmd+=( --set "$item" drawing=off icon.drawing=off icon.background.drawing=off icon="" label="" label.drawing=off width="$ICON_ITEM_WIDTH" )
    slot=$((slot+1))
  done

  if [ "$extra" -gt 0 ]; then
    cmd+=( --set "space.$ws.more"
      drawing=on
      width="$ICON_ITEM_WIDTH"
      icon.drawing=off
      label="+$extra"
      label.drawing=on
      label.padding_left=2
      label.padding_right=2
    )
  else
    cmd+=( --set "space.$ws.more" drawing=off label="" label.drawing=off )
  fi

  "${cmd[@]}"
}

refresh_all_or_subset() {
  local snapshot
  log_debug "Refreshing workspace icons for: $*"
  
  if ! snapshot="$(collect_windows "$@")"; then
    log_debug "Failed to collect windows data"
    return 1
  fi

  if [ "$#" -gt 0 ]; then
    local raw w
    for raw in "$@"; do
      w="$(normalize_ws "$raw")" || continue
      is_supported_ws "$w" || continue
      log_debug "Processing workspace $w"
      printf '%s\n' "$snapshot" | apps_for_ws "$w" | build_and_apply_updates "$w"
    done
  else
    # シェル互換性の確保: seqとjotの両方をサポート
    local w
    for w in $(seq "$MIN_WORKSPACE" "$MAX_WORKSPACE" 2>/dev/null || jot - "$MIN_WORKSPACE" "$MAX_WORKSPACE" 2>/dev/null || echo "$MIN_WORKSPACE $MAX_WORKSPACE" | awk '{for(i=$1;i<=$2;i++)print i}'); do
      log_debug "Processing all workspaces: $w"
      printf '%s\n' "$snapshot" | apps_for_ws "$w" | build_and_apply_updates "$w"
    done
  fi
  log_debug "Workspace icon refresh completed"
}

log_debug "Script started with args: $*, INFO: $INFO"

if [ -n "$1" ]; then
  refresh_all_or_subset "$1"
elif [ -n "$INFO" ]; then
  refresh_all_or_subset "$INFO"
else
  refresh_all_or_subset
fi

log_debug "Script completed"
