# ~/.config/aerospace/scripts/pseudo-restore.sh
# 隠しワークスペースにあるウィンドウを現在のワークスペースへ一枚だけ戻す。
# 疑似ミニマイズしたウィンドウを手軽に復帰させるために存在する。
# 関連ファイル: ~/.config/aerospace/scripts/pseudo-minimize.sh, ~/.config/aerospace/aerospace.toml
#!/usr/bin/env bash
set -euo pipefail

# フォーカス中ワークスペース名を取得。空なら終了。
current_ws="$(aerospace list-workspaces --focused --format '%{workspace}' 2>/dev/null | head -n1 | tr -d '[:space:]')"
[ -n "$current_ws" ] || exit 0

# hidden 接尾辞を剥がしたベースと、その hidden 名を生成。
base_ws="${current_ws%-hidden}"
[ -n "$base_ws" ] || exit 0
hidden_ws="${base_ws}-hidden"

# 隠し側の先頭ウィンドウIDを一つ取る。無ければ終了。
win_id="$(aerospace list-windows --workspace "$hidden_ws" --format '%{window-id}' 2>/dev/null | head -n1 | tr -d '[:space:]' || true)"
[ -n "$win_id" ] || exit 0

# ベースWSへ戻す。
aerospace move-node-to-workspace --window-id "$win_id" "$base_ws" 2>/dev/null || exit 0

# SketchyBar のアイコン反映を即座に促す。
sketchybar --trigger aerospace_workspace_change || true
