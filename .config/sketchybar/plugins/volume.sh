#!/bin/bash
# plugins/volume.sh
# 音量イベントを受け取りアイコンとラベルを即時更新する。
# 異常値を無視してバーの安定性を保つために存在する。
# 関連ファイル: sketchybarrc, plugins/battery.sh, plugins/network.sh, plugins/clock.sh

# The volume_change event supplies a $INFO variable in which the current volume
# percentage is passed to the script.

# デバッグログ設定（DEBUG_LOGが設定されている場合のみ有効）
if [ -n "$DEBUG_LOG" ]; then
  DEBUG_LOG="${DEBUG_LOG:-/tmp/sketchybar_volume_debug.log}"
  log_debug() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [VOLUME] $*" >> "$DEBUG_LOG"
  }
else
  log_debug() { :; }  # 何もしない
fi

log_debug "Volume event: SENDER=$SENDER, INFO=$INFO"

if [ "$SENDER" = "volume_change" ]; then
  VOLUME="$INFO"

  # ボリューム値の検証
  if [ -z "$VOLUME" ] || [ "$VOLUME" -lt 0 ] || [ "$VOLUME" -gt 100 ]; then
    log_debug "Invalid volume value: $VOLUME"
    exit 0
  fi

  case "$VOLUME" in
    [6-9][0-9]|100) ICON="󰕾"
    ;;
    [3-5][0-9]) ICON="󰖀"
    ;;
    [1-9]|[1-2][0-9]) ICON="󰕿"
    ;;
    *) ICON="󰖁"
  esac

  sketchybar --set "$NAME" icon="$ICON" label="$VOLUME%"
  log_debug "Volume updated: $ICON $VOLUME%"
fi
