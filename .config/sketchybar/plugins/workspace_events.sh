#!/usr/bin/env bash
# plugins/workspace_events.sh
# 超シンプルなワークスペースイベントハンドラ
# ロックを完全に排除し、即時実行で確実性を確保
# 関連ファイル: sketchybarrc, plugins/update_single_workspace.sh, plugins/aerospace.sh, plugins/update_workspace_icons.sh

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"

# 常に有効なデバッグログ
DEBUG_LOG="/tmp/sketchybar_simple.log"
echo "$(date '+%Y-%m-%d %H:%M:%S') [SIMPLE] Event: SENDER=$SENDER INFO=$INFO" >> "$DEBUG_LOG"

# 新しいスクリプトを優先的に使用
UPDATE_SCRIPT="$CONFIG_DIR/plugins/update_single_workspace.sh"

# スクリプトが存在し実行可能か確認
if [ ! -x "$UPDATE_SCRIPT" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') [SIMPLE] ERROR: Update script not found: $UPDATE_SCRIPT" >> "$DEBUG_LOG"
  exit 1
fi

# aerospaceコマンドの可用性を確認
echo "$(date '+%Y-%m-%d %H:%M:%S') [SIMPLE] Checking aerospace command..." >> "$DEBUG_LOG"
if command -v aerospace >/dev/null 2>&1; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') [SIMPLE] aerospace command found: $(which aerospace)" >> "$DEBUG_LOG"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') [SIMPLE] ERROR: aerospace command not found" >> "$DEBUG_LOG"
  # パスを追加してみる
  export PATH="/opt/homebrew/bin:$PATH"
  if command -v aerospace >/dev/null 2>&1; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SIMPLE] aerospace command found after PATH adjustment: $(which aerospace)" >> "$DEBUG_LOG"
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SIMPLE] ERROR: aerospace command still not found" >> "$DEBUG_LOG"
    exit 1
  fi
fi

# INFOからワークスペース番号を抽出（数字のみ、重複除去）
extract_workspaces() {
  printf '%s' "$1" | grep -Eo '[0-9]+' | awk '!seen[$0]++'
}

# フォーカス中のワークスペースを取得（失敗時は空文字を返す）
get_focused_workspace() {
  if command -v aerospace >/dev/null 2>&1; then
    aerospace list-workspaces --focused --format '%{workspace}' 2>/dev/null | tr -d '[:space:]'
  else
    echo ""
  fi
}

# 対象ワークスペースを決定する
targets=()

# 1) INFOに数字があればそれを優先
if ws_list="$(extract_workspaces "$INFO")" && [ -n "$ws_list" ]; then
  while IFS= read -r ws; do
    targets+=("$ws")
  done <<< "$ws_list"
  echo "$(date '+%Y-%m-%d %H:%M:%S') [SIMPLE] INFO-derived targets: ${targets[*]}" >> "$DEBUG_LOG"
fi

# 2) 見つからなければ現在フォーカス中のみ
if [ "${#targets[@]}" -eq 0 ]; then
  focused="$(get_focused_workspace)"
  if [ -n "$focused" ]; then
    targets=("$focused")
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SIMPLE] Focus-derived target: $focused" >> "$DEBUG_LOG"
  fi
fi

# 3) それでも空なら全ワークスペースを更新（従来動作）
if [ "${#targets[@]}" -eq 0 ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') [SIMPLE] No target found; updating all" >> "$DEBUG_LOG"
  DEBUG_LOG="/tmp/sketchybar_fast_update.log" "$UPDATE_SCRIPT" ""
else
  # 複数ターゲットをまとめて渡す
  echo "$(date '+%Y-%m-%d %H:%M:%S') [SIMPLE] Updating targets: ${targets[*]}" >> "$DEBUG_LOG"
  DEBUG_LOG="/tmp/sketchybar_fast_update.log" "$UPDATE_SCRIPT" "${targets[@]}"
fi

EXIT_CODE=$?
echo "$(date '+%Y-%m-%d %H:%M:%S') [SIMPLE] Execution completed with exit code: $EXIT_CODE" >> "$DEBUG_LOG"
