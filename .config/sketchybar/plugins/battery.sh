#!/bin/bash
# plugins/battery.sh
# バッテリー残量と充電状態をSketchyBarに表示する。
# 失敗時はアイテムを非表示にしてバーを汚さないために存在する。
# 関連ファイル: sketchybarrc, plugins/volume.sh, plugins/network.sh, plugins/ram_min.sh

# デバッグログ設定（DEBUG_LOGが設定されている場合のみ有効）
if [ -n "$DEBUG_LOG" ]; then
  DEBUG_LOG="${DEBUG_LOG:-/tmp/sketchybar_battery_debug.log}"
  log_debug() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [BATTERY] $*" >> "$DEBUG_LOG"
  }
else
  log_debug() { :; }  # 何もしない
fi

# バッテリー情報を安全に取得
get_battery_info() {
  local battery_info
  battery_info="$(pmset -g batt 2>/dev/null)"
  
  if [ -z "$battery_info" ]; then
    log_debug "No battery information available"
    return 1
  fi
  
  log_debug "Raw battery info: $battery_info"
  
  # パーセンテージを抽出（より堅牢な方法）- セミコロンなどの余分な文字を除去
  PERCENTAGE="$(echo "$battery_info" | awk '/InternalBattery/ {for(i=1;i<=NF;i++) if($i ~ /^[0-9]+%/) {print $i; exit}}' | tr -d '%' | tr -d ';' | sed 's/[^0-9]//g')"
  
  # 充電状態を確認
  if echo "$battery_info" | grep -q 'AC Power'; then
    CHARGING="1"
    log_debug "Battery charging: $PERCENTAGE%"
  else
    CHARGING=""
    log_debug "Battery discharging: $PERCENTAGE%"
  fi
  
  # パーセンテージの検証
  if [ -z "$PERCENTAGE" ] || [ "$PERCENTAGE" -lt 0 ] || [ "$PERCENTAGE" -gt 100 ]; then
    log_debug "Invalid battery percentage: $PERCENTAGE"
    return 1
  fi
  
  return 0
}

# バッテリー情報を取得
if ! get_battery_info; then
  # バッテリー情報が取得できない場合は非表示
  sketchybar --set "$NAME" drawing=off
  log_debug "Hiding battery item due to missing info"
  exit 0
fi

# バッテリーアイコンの選択
case "${PERCENTAGE}" in
  9[0-9]|100) ICON="" ;;
  [6-8][0-9]) ICON="" ;;
  [3-5][0-9]) ICON="" ;;
  [1-2][0-9]) ICON="" ;;
  *) ICON="" ;;
esac

# 充電中の場合は充電アイコンを使用
if [ -n "$CHARGING" ]; then
  ICON=""
fi

# The item invoking this script (name $NAME) will get its icon and label
# updated with the current battery status
sketchybar --set "$NAME" icon="$ICON" label="${PERCENTAGE}%" drawing=on
log_debug "Battery updated: $ICON ${PERCENTAGE}%"
