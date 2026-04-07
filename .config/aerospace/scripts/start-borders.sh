# ~/.config/aerospace/scripts/start-borders.sh
# AeroSpace 起動直後に JankyBorders を安全に起動する。
# AeroSpace の PATH に Homebrew が入らないため絶対パス起動のために存在する。
# 関連ファイル: ~/.config/aerospace/aerospace.toml, ~/.config/aerospace/scripts/common.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

[ -x "$BORDERS_BIN" ] || exit 0

# 二重起動を避ける。起動済みなら何もしない。
if /usr/bin/pgrep -x borders >/dev/null 2>&1; then
  exit 0
fi

exec "$BORDERS_BIN"
