# ~/.config/aerospace/scripts/pseudo-restore.sh
# 隠しワークスペースにあるウィンドウを現在のワークスペースへ一枚だけ戻す。
# 疑似ミニマイズしたウィンドウを手軽に復帰させるために存在する。
# 関連ファイル: ~/.config/aerospace/scripts/pseudo-minimize.sh, ~/.config/aerospace/scripts/common.sh, ~/.config/aerospace/aerospace.toml
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# フォーカス中ワークスペース名を取得。空なら終了。
current_ws="$(current_workspace)"
[ -n "$current_ws" ] || exit 0

# hidden 接尾辞を剥がしたベースと、その hidden 名を生成。
base_ws="${current_ws%-hidden}"
[ -n "$base_ws" ] || exit 0
hidden_ws="${base_ws}-hidden"

# 隠し側の先頭ウィンドウIDを一つ取る。無ければ終了。
win_id="$(first_window_id_in_workspace "$hidden_ws" || true)"
[ -n "$win_id" ] || exit 0

# ベースWSへ戻す。
"$AEROSPACE_BIN" move-node-to-workspace --window-id "$win_id" "$base_ws" 2>/dev/null || exit 0

# SketchyBar のアイコン反映を即座に促す。
trigger_workspace_change
