#!/bin/bash
# plugins/recording.sh
# Audio-only recorder for SketchyBar.
# Single click: start/pause/resume. Double click: save and stop.

ITEM_NAME="${NAME:-recording}"
OUTPUT_DIR="$HOME/Downloads"

PID_FILE="/tmp/sketchybar_recording.pid"
START_FILE="/tmp/sketchybar_recording_start"
STATUS_FILE="/tmp/sketchybar_recording_status"
PAUSE_FILE="/tmp/sketchybar_recording_pause"
PAUSED_TOTAL_FILE="/tmp/sketchybar_recording_paused_total"
LAST_CLICK_FILE="/tmp/sketchybar_recording_last_click"
LOG_FILE="/tmp/sketchybar_recording_ffmpeg.log"

DBL_CLICK_MS=450
DBL_CLICK_S="0.45"
AUDIO_DEVICE="${SKETCHYBAR_AUDIO_DEVICE:-0}"

ICON_IDLE="󰍮"
ICON_PAUSED="󰍯"
LABEL_SAVING="保存中..."

now_ms() {
  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import time
print(int(time.time() * 1000))
PY
    return
  fi
  if command -v perl >/dev/null 2>&1; then
    perl -MTime::HiRes=time -e 'printf "%d\n", int(time() * 1000)'
    return
  fi
  echo $(( $(date +%s) * 1000 ))
}

read_int() {
  local path="$1"
  if [ -f "$path" ]; then
    tr -cd '0-9' < "$path"
  fi
}

get_pid() {
  read_int "$PID_FILE"
}

is_running() {
  local pid
  pid="$(get_pid)"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

cleanup_state() {
  rm -f "$PID_FILE" "$START_FILE" "$STATUS_FILE" "$PAUSE_FILE" "$PAUSED_TOTAL_FILE"
}

set_status() {
  printf "%s" "$1" > "$STATUS_FILE"
}

get_status() {
  if [ -f "$STATUS_FILE" ]; then
    cat "$STATUS_FILE"
  fi
}

format_elapsed() {
  local elapsed="$1"
  [ -z "$elapsed" ] && elapsed=0
  if [ "$elapsed" -lt 0 ]; then
    elapsed=0
  fi

  local h=$((elapsed / 3600))
  local m=$(((elapsed % 3600) / 60))
  local s=$((elapsed % 60))

  if [ "$h" -gt 0 ]; then
    printf "%d:%02d:%02d" "$h" "$m" "$s"
  else
    printf "%02d:%02d" "$m" "$s"
  fi
}

elapsed_seconds() {
  local start paused_total pause_start now
  start="$(read_int "$START_FILE")"
  [ -z "$start" ] && echo 0 && return

  paused_total="$(read_int "$PAUSED_TOTAL_FILE")"
  [ -z "$paused_total" ] && paused_total=0

  if [ -f "$PAUSE_FILE" ]; then
    pause_start="$(read_int "$PAUSE_FILE")"
    [ -z "$pause_start" ] && pause_start="$start"
    echo $((pause_start - start - paused_total))
    return
  fi

  now="$(date +%s)"
  echo $((now - start - paused_total))
}

update_display() {
  local status icon label

  if ! is_running; then
    status="$(get_status)"
    cleanup_state
    if [ "$status" = "saving" ]; then
      sketchybar --set "$ITEM_NAME" \
        icon="$ICON_IDLE" icon.drawing=on \
        label="" label.drawing=off
      return
    fi
    sketchybar --set "$ITEM_NAME" \
      icon="$ICON_IDLE" icon.drawing=on \
      label="" label.drawing=off
    return
  fi

  status="$(get_status)"
  if [ -z "$status" ]; then
    status="recording"
    set_status "$status"
  fi

  if [ -f "$PAUSE_FILE" ] && [ "$status" != "paused" ]; then
    status="paused"
    set_status "$status"
  fi

  if [ "$status" = "paused" ] && [ ! -f "$PAUSE_FILE" ]; then
    status="recording"
    set_status "$status"
  fi

  case "$status" in
    saving)
      icon=""
      label="$LABEL_SAVING"
      ;;
    paused)
      icon="$ICON_PAUSED"
      label="$(format_elapsed "$(elapsed_seconds)")"
      ;;
    *)
      icon=""
      label="$(format_elapsed "$(elapsed_seconds)")"
      ;;
  esac

  case "$status" in
    saving)
      sketchybar --set "$ITEM_NAME" \
        icon="" icon.drawing=off \
        label="$label" label.drawing=on
      ;;
    paused)
      sketchybar --set "$ITEM_NAME" \
        icon="$icon" icon.drawing=on \
        label="$label" label.drawing=on
      ;;
    *)
      sketchybar --set "$ITEM_NAME" \
        icon="" icon.drawing=off \
        label="$label" label.drawing=on
      ;;
  esac
}

start_recording() {
  if ! command -v ffmpeg >/dev/null 2>&1; then
    sketchybar --set "$ITEM_NAME" \
      icon="$ICON_IDLE" icon.drawing=on \
      label="ffmpeg?" label.drawing=on
    return
  fi

  if is_running; then
    return
  fi

  mkdir -p "$OUTPUT_DIR"
  echo "$(date +%s)" > "$START_FILE"
  echo 0 > "$PAUSED_TOTAL_FILE"
  rm -f "$PAUSE_FILE"
  set_status "recording"

  local output
  output="$OUTPUT_DIR/recording_$(date +%Y%m%d_%H%M%S).mp3"

  ffmpeg -f avfoundation -i ":$AUDIO_DEVICE" \
    -c:a libmp3lame -q:a 2 \
    "$output" </dev/null > "$LOG_FILE" 2>&1 &
  echo $! > "$PID_FILE"

  sleep 0.2
  if ! is_running; then
    cleanup_state
    sketchybar --set "$ITEM_NAME" \
      icon="$ICON_IDLE" icon.drawing=on \
      label="mic?" label.drawing=on
    return
  fi

  update_display
}

pause_recording() {
  local pid
  pid="$(get_pid)"
  [ -z "$pid" ] && return
  [ -f "$PAUSE_FILE" ] && return

  echo "$(date +%s)" > "$PAUSE_FILE"
  set_status "paused"
  kill -STOP "$pid" 2>/dev/null
  update_display
}

resume_recording() {
  local pid pause_start paused_total now
  pid="$(get_pid)"
  [ -z "$pid" ] && return

  if [ -f "$PAUSE_FILE" ]; then
    pause_start="$(read_int "$PAUSE_FILE")"
    [ -z "$pause_start" ] && pause_start="$(date +%s)"
    paused_total="$(read_int "$PAUSED_TOTAL_FILE")"
    [ -z "$paused_total" ] && paused_total=0
    now="$(date +%s)"
    echo $((paused_total + now - pause_start)) > "$PAUSED_TOTAL_FILE"
    rm -f "$PAUSE_FILE"
  fi

  set_status "recording"
  kill -CONT "$pid" 2>/dev/null
  update_display
}

save_and_stop() {
  local pid
  pid="$(get_pid)"
  [ -z "$pid" ] && cleanup_state && update_display && return

  set_status "saving"
  if [ -f "$PAUSE_FILE" ]; then
    kill -CONT "$pid" 2>/dev/null
    rm -f "$PAUSE_FILE"
  fi

  kill -INT "$pid" 2>/dev/null
  update_display
}

toggle_pause_or_start() {
  if is_running; then
    if [ "$(get_status)" = "paused" ]; then
      resume_recording
    else
      pause_recording
    fi
  else
    start_recording
  fi
}

handle_single_click() {
  local expected_ms="$1"

  sleep "$DBL_CLICK_S"

  if [ "$(cat "$LAST_CLICK_FILE" 2>/dev/null)" = "$expected_ms" ]; then
    rm -f "$LAST_CLICK_FILE"
    toggle_pause_or_start
  fi
}

handle_toggle() {
  local now last status

  if ! is_running; then
    rm -f "$LAST_CLICK_FILE"
    start_recording
    return
  fi

  status="$(get_status)"
  if [ "$status" = "saving" ]; then
    return
  fi

  now="$(now_ms)"
  last="$(read_int "$LAST_CLICK_FILE")"

  if [ -n "$last" ] && [ $((now - last)) -lt "$DBL_CLICK_MS" ]; then
    rm -f "$LAST_CLICK_FILE"
    save_and_stop
    return
  fi

  printf "%s" "$now" > "$LAST_CLICK_FILE"
  ("$0" single_click "$now") &
}

case "$1" in
  toggle)
    handle_toggle
    ;;
  single_click)
    handle_single_click "$2"
    ;;
  start)
    start_recording
    ;;
  stop)
    save_and_stop
    ;;
  *)
    update_display
    ;;
esac
