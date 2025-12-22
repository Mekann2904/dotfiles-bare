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

# 2行表示: YYYY/MM/DD と HH:MM （曜日なしで等幅）
date_line=$(date '+%Y/%m/%d')
time_line=$(date '+%H:%M')

# 幅ぶれ防止のため、それぞれ固定長にパディング（10文字 + 5文字）
date_line_fixed=$(printf '%-10s' "$date_line")
time_line_fixed=$(printf '%-5s' "$time_line")

# 実際の改行を含む文字列を生成（printf -vで \n を実体化）
printf -v multiline_label "%s\n%s" "$date_line_fixed" "$time_line_fixed"

sketchybar --set "$NAME" label="$multiline_label"
log_debug "Clock updated: ${date_line_fixed} | ${time_line_fixed}"
