#!/usr/bin/env bash
# plugins/aerospace_focus.sh
# Workspace focus styling update (single-flight, batched sketchybar updates).
# Exists to avoid per-workspace aerospace calls under rapid switching.
# Related files: sketchybarrc, plugins/aerospace.sh

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
SKETCHYBAR_BIN="${BAR_NAME:-sketchybar}"
AEROSPACE_BIN=""

# Debug logging (optional)
if [ -n "${DEBUG_LOG:-}" ]; then
  DEBUG_LOG="${DEBUG_LOG:-/tmp/sketchybar_workspace_debug.log}"
  log_debug() { printf '%s [AEROSPACE_FOCUS] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$DEBUG_LOG"; }
else
  log_debug() { :; }
fi

# Tunables
DEFAULT_MIN_WORKSPACE=1
DEFAULT_MAX_WORKSPACE=7
MIN_WORKSPACE=${MIN_WORKSPACE:-$DEFAULT_MIN_WORKSPACE}
MAX_WORKSPACE=${WORKSPACE_RANGE_MAX:-${MAX_WORKSPACE:-$DEFAULT_MAX_WORKSPACE}}
EXTRA_WORKSPACES="${EXTRA_WORKSPACES:-T D}"

# Debounce + single-flight
LOCK_DIR="${FOCUS_LOCK_DIR:-/tmp/sketchybar_focus.lock}"
PENDING_FILE="${FOCUS_PENDING_FILE:-/tmp/sketchybar_focus.pending}"
LOCK_STALE_SECS="${FOCUS_LOCK_STALE_SECS:-3}"
DEBOUNCE_DELAY="${FOCUS_DEBOUNCE_DELAY:-0.06}"
MAX_RERUNS="${FOCUS_MAX_RERUNS:-3}"

lock_age_seconds() {
  local now mtime
  now=$(date +%s)
  mtime=$(stat -f %m "$LOCK_DIR" 2>/dev/null || stat -c %Y "$LOCK_DIR" 2>/dev/null || echo 0)
  [ "$mtime" -gt 0 ] || return 1
  echo $((now - mtime))
}

cleanup_lock() {
  [ -d "$LOCK_DIR" ] && rmdir "$LOCK_DIR" >/dev/null 2>&1
}

acquire_lock() {
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    return 0
  fi

  if [ -d "$LOCK_DIR" ]; then
    local age
    age=$(lock_age_seconds || echo 0)
    if [ "$age" -gt "$LOCK_STALE_SECS" ]; then
      rmdir "$LOCK_DIR" >/dev/null 2>&1 || true
      if mkdir "$LOCK_DIR" 2>/dev/null; then
        return 0
      fi
    fi
  fi

  printf '1' > "$PENDING_FILE" 2>/dev/null || true
  return 1
}

numeric_workspaces() {
  seq "$MIN_WORKSPACE" "$MAX_WORKSPACE" 2>/dev/null \
    || jot - "$MIN_WORKSPACE" "$MAX_WORKSPACE" 2>/dev/null \
    || echo "$MIN_WORKSPACE $MAX_WORKSPACE" | awk '{for(i=$1;i<=$2;i++)print i}'
}

workspace_list() {
  local w
  numeric_workspaces
  for w in $EXTRA_WORKSPACES; do
    printf '%s\n' "$w"
  done
}

ensure_aerospace() {
  AEROSPACE_BIN="$(type -P aerospace 2>/dev/null || true)"
  if [ -z "$AEROSPACE_BIN" ]; then
    export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
    AEROSPACE_BIN="$(type -P aerospace 2>/dev/null || true)"
  fi
  [ -n "$AEROSPACE_BIN" ]
}

focused_workspace() {
  "$AEROSPACE_BIN" list-workspaces --focused --format '%{workspace}' 2>/dev/null | awk 'NR==1 { gsub(/[[:space:]]+/, ""); print; exit }'
}

apply_focus_state() {
  local focused
  focused="$(focused_workspace)"
  [ -n "$focused" ] || return 0

  local cmd=("$SKETCHYBAR_BIN")
  local ws
  for ws in $(workspace_list); do
    if [ "$ws" = "$focused" ]; then
      cmd+=(--set "space.$ws"
        icon.color=0xFFFFFFFF
        icon.font="Hack Nerd Font:Bold:16.0"
        background.drawing=off
      )
      cmd+=(--set "space.$ws.underline"
        drawing=on
        background.drawing=on
      )
    else
      cmd+=(--set "space.$ws"
        icon.color=0x88FFFFFF
        icon.font="Hack Nerd Font:Semibold:16.0"
        background.drawing=off
      )
      cmd+=(--set "space.$ws.underline"
        drawing=off
        background.drawing=off
      )
    fi
  done

  "${cmd[@]}" >/dev/null 2>&1 || true
  log_debug "Focused workspace: $focused"
}

main() {
  ensure_aerospace || return 0

  if ! acquire_lock; then
    log_debug "Lock busy; marked pending"
    return 0
  fi
  trap cleanup_lock EXIT INT TERM

  local runs=0
  while [ "$runs" -lt "$MAX_RERUNS" ]; do
    runs=$((runs + 1))
    if [ "$DEBOUNCE_DELAY" != "0" ] && [ -n "$DEBOUNCE_DELAY" ]; then
      sleep "$DEBOUNCE_DELAY"
    fi

    apply_focus_state

    if [ -f "$PENDING_FILE" ]; then
      rm -f "$PENDING_FILE" 2>/dev/null || true
      continue
    fi
    break
  done
}

main "$@" || true
exit 0
