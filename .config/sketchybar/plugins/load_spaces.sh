#!/bin/bash
# plugins/load_spaces.sh
# 予備のワークスペース追加スクリプト（現在未使用）。
# 将来の拡張やデバッグ用に簡易追加処理を残す目的で存在する。
# 関連ファイル: sketchybarrc, plugins/aerospace.sh, plugins/update_single_workspace.sh, plugins/workspace_events.sh

# NOT IN USE
for sid in $(aerospace list-workspaces --monitor 1 --empty no); do
    sketchybar --add item space.$sid left \
        --subscribe space.$sid aerospace_workspace_change \
        --set space.$sid \
        background.color=0x44ffffff \
        background.corner_radius=5 \
        background.height=20 \
        background.drawing=off \
        label="$sid" \
        click_script="aerospace workspace $sid" \
        script="$CONFIG_DIR/plugins/aerospace.sh $sid"
done
