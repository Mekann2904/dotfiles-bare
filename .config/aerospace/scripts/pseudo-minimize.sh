# ~/.config/aerospace/scripts/pseudo-minimize.sh
# フォーカス中ウィンドウを隠しワークスペースへ退避し、hidden 上では復帰動作にフォールバックする。
# 最低限の疑似ミニマイズ操作と hidden ワークスペースからの即時復帰を両立させるために存在する。
# 関連ファイル: ~/.config/aerospace/scripts/pseudo-restore.sh, ~/.config/aerospace/aerospace.toml
#!/usr/bin/env bash
set -euo pipefail

# 現在のワークスペース（hidden の場合もある）を取得。無ければ終了。
current_ws="$(aerospace list-workspaces --focused --format '%{workspace}' 2>/dev/null | head -n1 | tr -d '[:space:]')"
[ -n "$current_ws" ] || exit 0

# hidden 上で alt-m を押した場合は疑似復帰（alt-shift-m 相当）へ切り替える。
if [[ "$current_ws" == *"-hidden" ]]; then
  /Users/mekann/.config/aerospace/scripts/pseudo-restore.sh
  exit 0
fi

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
