#!/bin/sh
# plugins/space.sh
# SketchyBarのスペースアイテム背景表示を切り替える最小スクリプト。
# 選択状態だけに責務を限定し副作用を避けるために存在する。
# 関連ファイル: sketchybarrc, plugins/aerospace.sh, plugins/update_single_workspace.sh, plugins/space_windows.sh

# The $SELECTED variable is available for space components and indicates if
# the space invoking this script (with name: $NAME) is currently selected:
# https://felixkratz.github.io/SketchyBar/config/components#space----associate-mission-control-spaces-with-an-item

sketchybar --set "$NAME" background.drawing="$SELECTED"
