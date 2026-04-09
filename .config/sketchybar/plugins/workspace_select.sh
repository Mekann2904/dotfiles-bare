# ~/.config/sketchybar/plugins/workspace_select.sh
# ワークスペース選択後に軽い更新イベントを即時送る。
# クリック操作の真値整合を保ったままフォーカス更新の待ちを減らすために存在する。
# 関連ファイル: sketchybarrc, plugins/workspace_events.sh, plugins/update_single_workspace.sh
#!/usr/bin/env bash

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
TARGET_WORKSPACE="${1:-}"

[ -n "$TARGET_WORKSPACE" ] || exit 0
command -v aerospace >/dev/null 2>&1 || exit 0
command -v sketchybar >/dev/null 2>&1 || exit 0

if aerospace workspace "$TARGET_WORKSPACE" 2>/dev/null; then
  sketchybar --trigger workspace_manual_change INFO="$TARGET_WORKSPACE" >/dev/null 2>&1 || true
fi

exit 0
