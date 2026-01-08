# ~/.config/sketchybar/plugins/hidden_windows.sh
# 現在ワークスペースの疑似ミニマイズ中ウィンドウのアイコンを並べて表示する。
# 個別アイコンを押したときに元のワークスペースへ即復帰させるために存在する。
# 関連ファイル: sketchybarrc, plugins/update_single_workspace.sh, ~/.config/aerospace/scripts/pseudo-restore.sh
#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
SCRIPT_SELF="$CONFIG_DIR/plugins/hidden_windows.sh"

# アイコン数とサイズは環境変数で調整可能。
SLOTS=${HIDDEN_ICON_SLOTS:-4}
# ワークスペース表示のアイコン設定と揃える。
ICON_WIDTH=${HIDDEN_ICON_WIDTH:-16}
ICON_HEIGHT=${HIDDEN_ICON_HEIGHT:-16}
ICON_SCALE=${HIDDEN_ICON_SCALE:-0.8}
# ワークスペースアイコンと完全一致させる（背景は高さのみ指定）。
ICON_BG_HEIGHT=${HIDDEN_ICON_BG_HEIGHT:-16}
ITEM_WIDTH=${HIDDEN_ITEM_WIDTH:-24}

# フォーカス中ワークスペース名を取得。空なら空文字を返すだけ。
focused_workspace() {
  aerospace list-workspaces --focused --format '%{workspace}' 2>/dev/null | head -n1 | tr -d '[:space:]'
}

# フォーカスワークスペース名から末尾の -hidden を剥がした「ベース」を返す。
base_workspace() {
  local ws
  ws="$(focused_workspace)"
  ws="${ws%-hidden}"
  printf '%s\n' "$ws"
}

# 個別ウィンドウを現在のワークスペースへ戻す。
restore_window() {
  local win_id="$1"
  [ -n "$win_id" ] || exit 0

  local ws
  ws="$(base_workspace)"
  [ -n "$ws" ] || exit 0

  aerospace move-node-to-workspace --window-id "$win_id" "$ws" 2>/dev/null || exit 0

  # アイコン更新が即時反映されるよう、既存のイベントにフックする。
  sketchybar --trigger aerospace_workspace_change || true
}

# restore サブコマンド時は即復帰して終了。
if [ "${1:-}" = "restore" ]; then
  restore_window "${2:-}"
  exit 0
fi

WS="$(base_workspace)"

# フォーカスが無ければ全アイテムを隠す。
if [ -z "$WS" ]; then
  sketchybar --set hidden drawing=off icon.drawing=off label="" label.drawing=off
  for slot in $(seq 1 "$SLOTS"); do
    sketchybar --set "hidden.icon${slot}" drawing=off icon.background.drawing=off icon.drawing=off click_script=""
  done
  exit 0
fi

HIDDEN_WS="${WS}-hidden"

# window-id と app-name を取得。移動途中の例外は無視する。
hidden_list=$(aerospace list-windows --workspace "$HIDDEN_WS" --format '%{window-id}|%{app-name}' 2>/dev/null || true)

hidden_count=$(printf '%s\n' "$hidden_list" | grep -c '|' || true)

# 何も無ければ親アイコンも含めて隠す。
if [ "$hidden_count" -eq 0 ]; then
  sketchybar --set hidden drawing=off icon.drawing=off label="" label.drawing=off
  for slot in $(seq 1 "$SLOTS"); do
    sketchybar --set "hidden.icon${slot}" drawing=off icon.background.drawing=off icon.drawing=off click_script=""
  done
  exit 0
fi

cmd=(sketchybar)

# 親アイコンは非表示（スクリプト実行専用）。
cmd+=(--set hidden drawing=off icon.drawing=off label="" label.drawing=off)

slot=1
extra_count=0
extra_first_id=""

while IFS='|' read -r win_id app_name; do
  [ -n "$win_id" ] || continue
  [ -n "$app_name" ] || app_name="Unknown"

  escaped_app=$(printf '%s' "$app_name" | sed -e 's/[\\"]/\\&/g')

  [ "$slot" -le "$SLOTS" ] || break
  item="hidden.icon${slot}"
  cmd+=(--set "$item" \
    drawing=on \
    width="$ITEM_WIDTH" \
    icon.drawing=off \
    label.drawing=off \
    background.drawing=on \
    background.image="app.${escaped_app}" \
    background.image.scale="$ICON_SCALE" \
    background.height="$ICON_BG_HEIGHT" \
    background.corner_radius=3 \
    background.y_offset=0 \
    padding_left=0 \
    padding_right=0 \
    click_script="$SCRIPT_SELF restore $win_id"
  )
  slot=$((slot + 1))
done < <(echo "$hidden_list")

# 余りスロットは非表示に。
while [ "$slot" -le "$SLOTS" ]; do
  item="hidden.icon${slot}"
  cmd+=(--set "$item" drawing=off icon.drawing=off icon.background.drawing=off click_script="")
  slot=$((slot + 1))
done

"${cmd[@]}"
