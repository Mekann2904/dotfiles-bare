#!/usr/bin/env bash
# plugins/wallpaper.sh
# デスクトップ壁紙を指定パスに切り替えるシンプルなコマンド。
# アバターポップアップから即時に壁紙を切り替えるために存在する。
# 関連ファイル: sketchybarrc, plugins/clock.sh, plugins/tasks.sh, plugins/user.png

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"

WALLPAPER_PATH="$1"
PARENT_ITEM="${2:-avatar}"

# DEBUG_LOG 環境変数が設定されている場合のみログを残す。
if [ -n "$DEBUG_LOG" ]; then
  DEBUG_LOG="${DEBUG_LOG:-/tmp/sketchybar_wallpaper_debug.log}"
  log_debug() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WALLPAPER] $*" >> "$DEBUG_LOG"
  }
else
  log_debug() { :; }
fi

if [ -z "$WALLPAPER_PATH" ]; then
  log_debug "壁紙パスが渡されていないため終了"
  exit 1
fi

if [ ! -f "$WALLPAPER_PATH" ]; then
  log_debug "壁紙が見つかりません: $WALLPAPER_PATH"
  sketchybar --set "$PARENT_ITEM" popup.drawing=off
  exit 1
fi

osascript -e "tell application \"System Events\" to set picture of every desktop to (POSIX file \"$WALLPAPER_PATH\")" >/dev/null 2>&1
status=$?

if [ $status -ne 0 ]; then
  log_debug "osascriptが失敗しました (status=$status)"
else
  log_debug "壁紙を切り替えました: $WALLPAPER_PATH"
fi

sketchybar --set "$PARENT_ITEM" popup.drawing=off

exit $status
