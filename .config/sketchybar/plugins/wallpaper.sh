#!/usr/bin/env bash
# plugins/wallpaper.sh
# デスクトップ壁紙を指定パスに切り替えるシンプルなコマンド。
# アバターポップアップから即時に壁紙を切り替えるために存在する。
# 関連ファイル: sketchybarrc, plugins/clock.sh, plugins/wallpaper_list.sh, plugins/user.png

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

# 全モニターへ確実に反映するため、各 desktop を明示的に更新する。
apply_output=$(
  osascript \
    -e 'on run argv' \
    -e 'set wallpaperPath to item 1 of argv' \
    -e 'set wallpaperFile to POSIX file wallpaperPath' \
    -e 'set appliedCount to 0' \
    -e 'tell application "System Events"' \
    -e 'repeat with currentDesktop in desktops' \
    -e 'set picture of currentDesktop to wallpaperFile' \
    -e 'set appliedCount to appliedCount + 1' \
    -e 'end repeat' \
    -e 'end tell' \
    -e 'return appliedCount' \
    -e 'end run' \
    "$WALLPAPER_PATH" 2>&1
)
status=$?

if [ $status -ne 0 ]; then
  log_debug "osascriptが失敗しました (status=$status): $apply_output"
else
  log_debug "壁紙を切り替えました: $WALLPAPER_PATH (${apply_output} desktops)"
fi

sketchybar --set "$PARENT_ITEM" popup.drawing=off

exit $status
