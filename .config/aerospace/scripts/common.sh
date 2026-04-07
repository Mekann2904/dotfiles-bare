# ~/.config/aerospace/scripts/common.sh
# AeroSpace 用スクリプトの共通パスと共通関数をまとめる。
# Homebrew 配下の実行ファイルを毎回安全に呼ぶために存在する。
# 関連ファイル: ~/.config/aerospace/aerospace.toml, ~/.config/aerospace/scripts/pseudo-minimize.sh, ~/.config/aerospace/scripts/workspace-change-hook.sh

AEROSPACE_BIN="${AEROSPACE_BIN:-/opt/homebrew/bin/aerospace}"
SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-/opt/homebrew/bin/sketchybar}"
BORDERS_BIN="${BORDERS_BIN:-/opt/homebrew/bin/borders}"
UPDATE_WORKSPACE_ICONS_SCRIPT="${UPDATE_WORKSPACE_ICONS_SCRIPT:-$HOME/.config/sketchybar/plugins/update_workspace_icons.sh}"

current_workspace() {
  "$AEROSPACE_BIN" list-workspaces --focused --format '%{workspace}' 2>/dev/null | head -n1 | tr -d '[:space:]'
}

focused_window_id() {
  "$AEROSPACE_BIN" list-windows --focused --format '%{window-id}' 2>/dev/null | head -n1 | tr -d '[:space:]'
}

first_window_id_in_workspace() {
  local workspace="$1"
  "$AEROSPACE_BIN" list-windows --workspace "$workspace" --format '%{window-id}' 2>/dev/null | head -n1 | tr -d '[:space:]'
}

run_if_executable() {
  local binary="$1"
  shift
  [ -x "$binary" ] || return 0
  "$binary" "$@"
}

trigger_workspace_change() {
  run_if_executable "$SKETCHYBAR_BIN" --trigger aerospace_workspace_change "$@" || true

  if [ -x "$UPDATE_WORKSPACE_ICONS_SCRIPT" ]; then
    "$UPDATE_WORKSPACE_ICONS_SCRIPT" || true
  fi
}
