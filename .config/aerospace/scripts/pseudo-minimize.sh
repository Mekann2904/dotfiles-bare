# ~/.config/aerospace/scripts/pseudo-minimize.sh
# フォーカス中ウィンドウを隠しワークスペースへ退避し、hidden 上では復帰動作にフォールバックする。
# 最低限の疑似ミニマイズ操作と hidden ワークスペースからの即時復帰を両立させるために存在する。
# 関連ファイル: ~/.config/aerospace/scripts/pseudo-restore.sh, ~/.config/aerospace/scripts/common.sh, ~/.config/aerospace/aerospace.toml
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 共通の絶対パス定義を読み込み、AeroSpace の PATH に依存しないようにする。
source "$SCRIPT_DIR/common.sh"

# 現在のワークスペース（hidden の場合もある）を取得。無ければ終了。
current_ws="$(current_workspace)"
[ -n "$current_ws" ] || exit 0

# hidden 上で alt-m を押した場合は疑似復帰（alt-shift-m 相当）へ切り替える。
if [[ "$current_ws" == *"-hidden" ]]; then
  /bin/bash "$SCRIPT_DIR/pseudo-restore.sh"
  exit 0
fi

# hidden 接尾辞を剥がした「ベースWS」を求める。
base_ws="${current_ws%-hidden}"
[ -n "$base_ws" ] || exit 0

# フォーカス中ウィンドウID。存在しなければ何もしない。
win_id="$(focused_window_id)"
[ -n "$win_id" ] || exit 0

hidden_ws="${base_ws}-hidden"

# 対象ウィンドウをベースWS専用の hidden へ退避させる。
"$AEROSPACE_BIN" move-node-to-workspace --window-id "$win_id" "$hidden_ws" 2>/dev/null || exit 0

# SketchyBar 側の hidden_windows.sh に即時反映させる。
trigger_workspace_change
