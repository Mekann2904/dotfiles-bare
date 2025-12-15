#!/usr/bin/env bash
# plugins/workspace_events.sh
# 超シンプルなワークスペースイベントハンドラ
# ロックを完全に排除し、即時実行で確実性を確保
# 関連ファイル: sketchybarrc, plugins/update_single_workspace.sh, plugins/aerospace.sh, plugins/update_workspace_icons.sh

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
UPDATE_SCRIPT="$CONFIG_DIR/plugins/update_single_workspace.sh"

# --- Debug log setup (open FD once) ---
if [ -n "${DEBUG_LOG:-}" ]; then
  DEBUG_LOG="${DEBUG_LOG:-/tmp/sketchybar_simple.log}"
elif [ "${SKETCHYBAR_WS_DEBUG:-}" = "1" ]; then
  DEBUG_LOG="/tmp/sketchybar_simple.log"
else
  DEBUG_LOG=""
fi

if [ -n "$DEBUG_LOG" ]; then
  exec 3>>"$DEBUG_LOG"
  log() { printf '%s [SIMPLE] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&3; }
else
  log() { :; }
fi

log "Event: SENDER=${SENDER:-} INFO=${INFO:-}"

# --- Preflight checks ---
if [ ! -x "$UPDATE_SCRIPT" ]; then
  log "ERROR: Update script not found or not executable: $UPDATE_SCRIPT"
  [ -n "$DEBUG_LOG" ] && exec 3>&-
  exit 1
fi

# Resolve aerospace once
AEROSPACE_BIN="$(type -P aerospace 2>/dev/null || true)"
if [ -z "$AEROSPACE_BIN" ]; then
  export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
  AEROSPACE_BIN="$(type -P aerospace 2>/dev/null || true)"
fi
if [ -z "$AEROSPACE_BIN" ]; then
  log "ERROR: aerospace command not found"
  [ -n "$DEBUG_LOG" ] && exec 3>&-
  exit 1
fi
log "aerospace command: $AEROSPACE_BIN"

# --- Helpers ---
extract_workspaces() {
  local s="$1" tok out=""
  s="${s//[^0-9]/ }"
  for tok in $s; do
    case " $out " in
      *" $tok "*) : ;;
      *) out="$out $tok" ;;
    esac
  done
  for tok in $out; do
    [ -n "$tok" ] && printf '%s\n' "$tok"
  done
}

get_focused_workspace() {
  "$AEROSPACE_BIN" list-workspaces --focused --format '%{workspace}' 2>/dev/null | tr -d '[:space:]'
}

# --- Target resolution ---
targets=()

if [ -n "${INFO:-}" ]; then
  if ws_list="$(extract_workspaces "$INFO")" && [ -n "$ws_list" ]; then
    while IFS= read -r ws; do
      targets+=("$ws")
    done <<EOF
$ws_list
EOF
    log "INFO-derived targets: ${targets[*]}"
  fi
fi

if [ "${#targets[@]}" -eq 0 ]; then
  focused="$(get_focused_workspace)"
  if [ -n "$focused" ]; then
    targets=("$focused")
    log "Focus-derived target: $focused"
  fi
fi

# --- Execute update ---
if [ "${#targets[@]}" -eq 0 ]; then
  log "No target found; updating all"
  DEBUG_LOG="/tmp/sketchybar_fast_update.log" "$UPDATE_SCRIPT"
  EXIT_CODE=$?
else
  log "Updating targets: ${targets[*]}"
  DEBUG_LOG="/tmp/sketchybar_fast_update.log" "$UPDATE_SCRIPT" "${targets[@]}"
  EXIT_CODE=$?
fi

log "Execution completed with exit code: $EXIT_CODE"
[ -n "$DEBUG_LOG" ] && exec 3>&-
exit "$EXIT_CODE"
