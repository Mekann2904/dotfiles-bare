# ~/.config/aerospace/scripts/move-workspace-prev-visible.sh
# フォーカス中ウィンドウをベースワークスペース(1〜7)の前へ移動する。
# hidden や特別ワークスペースを跨がずに安全に逆方向移動するために存在する。
# 関連ファイル: ~/.config/aerospace/scripts/move-workspace-next-visible.sh, ~/.config/aerospace/scripts/common.sh, ~/.config/aerospace/aerospace.toml
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

order=(1 2 3 4 5 6 7)

current_ws="$(current_workspace)"
[ -n "$current_ws" ] || exit 0

base_ws="${current_ws%-hidden}"
[ -n "$base_ws" ] || exit 0

idx=-1
for i in "${!order[@]}"; do
  if [ "$base_ws" = "${order[$i]}" ]; then
    idx="$i"
    break
  fi
done

if [ "$idx" -lt 0 ]; then
  prev_ws="${order[0]}"
else
  prev_index=$(( (idx - 1 + ${#order[@]}) % ${#order[@]} ))
  prev_ws="${order[$prev_index]}"
fi

"$AEROSPACE_BIN" move-node-to-workspace --focus-follows-window "$prev_ws"
