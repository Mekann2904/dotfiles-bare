# ~/.config/aerospace/scripts/pseudo-minimize.sh
# フォーカス中ウィンドウを現在のワークスペース用の隠しワークスペースへ退避する。
# 最低限の疑似ミニマイズ操作を提供するために存在する。
# 関連ファイル: ~/.config/aerospace/scripts/pseudo-restore.sh, ~/.config/aerospace/aerospace.toml
#!/usr/bin/env bash
set -euo pipefail

# 現在のワークスペース（hidden の場合もある）を取得。無ければ終了。
current_ws="$(aerospace list-workspaces --focused --format '%{workspace}' 2>/dev/null | head -n1 | tr -d '[:space:]')"
[ -n "$current_ws" ] || exit 0

# hidden 接尾辞を剥がした「ベースWS」を求める。
base_ws="${current_ws%-hidden}"
[ -n "$base_ws" ] || exit 0

# フォーカス中ウィンドウID。存在しなければ何もしない。
win_id="$(aerospace list-windows --focused --format '%{window-id}' 2>/dev/null | head -n1 | tr -d '[:space:]')"
[ -n "$win_id" ] || exit 0

hidden_ws="${base_ws}-hidden"

# 対象ウィンドウをベースWS専用の hidden へ退避させる。
aerospace move-node-to-workspace --window-id "$win_id" "$hidden_ws" 2>/dev/null || exit 0

# SketchyBar 側の hidden_windows.sh に即時反映させる。
sketchybar --trigger aerospace_workspace_change || true
