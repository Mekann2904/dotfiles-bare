#!/bin/bash
# plugins/clock.sh
# 現在日時をキャッシュしつつSketchyBarラベルに表示する。
# 無駄な計算とログ肥大を抑えつつ時間情報を提供するために存在する。
# 関連ファイル: sketchybarrc, plugins/volume.sh, plugins/battery.sh, plugins/network.sh

# The $NAME variable is passed from sketchybar and holds the name of
# the item invoking this script:
# https://felixkratz.github.io/SketchyBar/config/events#events-and-scripting

# デバッグログ設定（DEBUG_LOGが設定されている場合のみ有効）
if [ -n "$DEBUG_LOG" ]; then
  DEBUG_LOG="${DEBUG_LOG:-/tmp/sketchybar_clock_debug.log}"
  log_debug() {
    # 1分に1回だけログを記録（ログファイルが大きくなりすぎないように）
    local current_minute=$(date '+%M')
    if [ "$current_minute" != "${LAST_LOG_MINUTE:-}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') [CLOCK] $*" >> "$DEBUG_LOG"
      LAST_LOG_MINUTE="$current_minute"
    fi
  }
else
  log_debug() { :; }  # 何もしない
fi

# キャッシュファイルのパス
CACHE_FILE="/tmp/sketchybar_clock_cache"

# 日付部分をキャッシュから取得または計算
get_cached_date() {
  local current_date=$(date '+%Y%m%d')
  local cached_date=""
  local cached_date_part=""
  
  # キャッシュファイルが存在する場合、読み取り
  if [ -f "$CACHE_FILE" ]; then
    cached_date=$(head -n1 "$CACHE_FILE")
    cached_date_part=$(tail -n1 "$CACHE_FILE")
  fi
  
  # 日付が変わった場合またはキャッシュがない場合、再計算
  if [ "$cached_date" != "$current_date" ] || [ -z "$cached_date_part" ]; then
    # 曜日を漢字で取得する関数
    get_kanji_day() {
      local day_num=$(date '+%u')
      case $day_num in
        1) echo "月" ;;
        2) echo "火" ;;
        3) echo "水" ;;
        4) echo "木" ;;
        5) echo "金" ;;
        6) echo "土" ;;
        7) echo "日" ;;
        *) echo "?" ;;
      esac
    }
    
    local month_day=$(date '+%m月%d日')
    local kanji_day=$(get_kanji_day)
    cached_date_part="${month_day}（${kanji_day}）"
    
    # キャッシュを更新
    echo "$current_date" > "$CACHE_FILE"
    echo "$cached_date_part" >> "$CACHE_FILE"
    
    log_debug "Date cache updated: $cached_date_part"
  fi
  
  echo "$cached_date_part"
}

# 日付部分をキャッシュから取得
date_part=$(get_cached_date)

# 時間部分のみを計算
time_part=$(date '+%H:%M:%S')

current_time="${date_part} ${time_part}"

# 日付の取得に失敗した場合のフォールバック
if [ -z "$current_time" ]; then
  current_time="$(date '+%H:%M:%S')"
  log_debug "Fallback to basic time format"
fi

sketchybar --set "$NAME" label="$current_time"
log_debug "Clock updated: $current_time"
