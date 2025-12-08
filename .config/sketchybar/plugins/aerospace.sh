#!/usr/bin/env bash
# plugins/aerospace.sh
# 個別ワークスペースタイルの色とフォントを更新する最小スクリプト。
# フォーカス状態を視覚化しつつ余計な処理を避けるために存在する。
# 関連ファイル: sketchybarrc, plugins/workspace_events.sh, plugins/update_workspace_icons.sh, plugins/icon_map_fn.sh

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"

# デバッグログ設定（DEBUG_LOGが設定されている場合のみ有効）
if [ -n "$DEBUG_LOG" ]; then
  DEBUG_LOG="${DEBUG_LOG:-/tmp/sketchybar_workspace_debug.log}"
  log_debug() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [AEROSPACE] $*" >> "$DEBUG_LOG"
  }
else
  log_debug() { :; }  # 何もしない
fi

workspace_id="$1"

# 現在フォーカスされているワークスペースを取得
get_focused_workspace() {
  if command -v aerospace >/dev/null 2>&1; then
    # 出力から改行と余分な空白を除去
    aerospace list-workspaces --focused --format '%{workspace}' 2>/dev/null | tr -d '\n' | tr -d ' ' || echo ""
  else
    log_debug "aerospace command not found"
    echo ""
  fi
}

# 色とフォントだけ切り替え、アイコン更新はworkspace_events.sh側で集約する。
FOCUSED_WORKSPACE="$(get_focused_workspace)"
log_debug "Workspace ID: '$workspace_id', Focused Workspace: '$FOCUSED_WORKSPACE'"

# デバッグ: 変数の値を詳細にログに記録
log_debug "Comparison: workspace_id='$workspace_id' FOCUSED_WORKSPACE='$FOCUSED_WORKSPACE'"

if [ "$workspace_id" = "$FOCUSED_WORKSPACE" ]; then
  # フォーカスされているワークスペース：明るい白色の数字
  sketchybar --set "$NAME" \
    icon.color=0xFFFFFFFF \
    icon.font="SF Pro:Bold:16.0"
  log_debug "Set workspace $workspace_id as focused with bright color"
else
  # フォーカスされていないワークスペース：半透明の白色の数字
  sketchybar --set "$NAME" \
    icon.color=0x88FFFFFF \
    icon.font="SF Pro:Semibold:16.0"
  log_debug "Set workspace $workspace_id as unfocused"
fi
