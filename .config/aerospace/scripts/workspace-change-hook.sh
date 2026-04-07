# ~/.config/aerospace/scripts/workspace-change-hook.sh
# ワークスペース変更時の SketchyBar 更新を一箇所で安全に処理する。
# AeroSpace のコールバック失敗を減らし、更新処理を単純化するために存在する。
# 関連ファイル: ~/.config/aerospace/aerospace.toml, ~/.config/aerospace/scripts/common.sh, ~/.config/sketchybar/plugins/update_workspace_icons.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

FOCUSED_WORKSPACE="${AEROSPACE_FOCUSED_WORKSPACE:-}"
PREV_WORKSPACE="${AEROSPACE_PREV_WORKSPACE:-}"

export FOCUSED_WORKSPACE PREV_WORKSPACE
trigger_workspace_change "FOCUSED_WORKSPACE=$FOCUSED_WORKSPACE" "PREV_WORKSPACE=$PREV_WORKSPACE"
