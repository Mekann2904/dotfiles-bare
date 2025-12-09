# ~/.config/aerospace/scripts/pseudo-restore.sh
# 隠しワークスペースにあるウィンドウを現在のワークスペースへ一枚だけ戻す。
# 疑似ミニマイズしたウィンドウを手軽に復帰させるために存在する。
# 関連ファイル: ~/.config/aerospace/scripts/pseudo-minimize.sh, ~/.config/aerospace/aerospace.toml
#!/usr/bin/env bash
set -euo pipefail

# フォーカス中ワークスペース名を取得。空なら終了。
WS="$(aerospace list-workspaces --focused --format '%{workspace}' | head -n1 | tr -d '[:space:]')"
if [ -z "$WS" ]; then
  exit 0
fi

HIDDEN_WS="${WS}-hidden"

# 隠し側の先頭ウィンドウIDを一つ取る。無ければ終了。
ID="$(aerospace list-windows --workspace "$HIDDEN_WS" --format '%{window-id}' | head -n1 | tr -d '[:space:]')"
if [ -z "$ID" ]; then
  exit 0
fi

# 見つかったウィンドウを現在のワークスペースに戻す。
aerospace move-node-to-workspace --window-id "$ID" "$WS"
