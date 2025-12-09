# ~/.config/aerospace/scripts/pseudo-minimize.sh
# フォーカス中ウィンドウを現在のワークスペース用の隠しワークスペースへ退避する。
# 最低限の疑似ミニマイズ操作を提供するために存在する。
# 関連ファイル: ~/.config/aerospace/scripts/pseudo-restore.sh, ~/.config/aerospace/aerospace.toml
#!/usr/bin/env bash
set -euo pipefail

# フォーカス中ワークスペース名を取得。空なら何もしない。
WS="$(aerospace list-workspaces --focused --format '%{workspace}' | head -n1 | tr -d '[:space:]')"
if [ -z "$WS" ]; then
  exit 0
fi

HIDDEN_WS="${WS}-hidden"

# 現在フォーカスしているウィンドウを隠しワークスペースに移動する。
# フォーカスが無いときはコマンド側で何も起きない。
aerospace move-node-to-workspace "$HIDDEN_WS"
