# ~/.config/aerospace/scripts/workspace-prev-visible.sh
# ベースワークスペース(1〜7)のみを前に巡回する。
# 隠しワークスペースを経由しない後退移動を保証するために存在する。
# 関連ファイル: ~/.config/aerospace/scripts/workspace-next-visible.sh, ~/.config/aerospace/aerospace.toml, ~/.config/aerospace/scripts/pseudo-minimize.sh, ~/.config/aerospace/scripts/pseudo-restore.sh
#!/usr/bin/env bash
set -euo pipefail

order=(1 2 3 4 5 6 7)

log_start() {
  printf '%s prev start\n' "$(date '+%F %T')" >> /tmp/aerospace-workspace-cycle.log 2>/dev/null || true
}

log() {
  printf '%s prev base=%s prev=%s\n' "$(date '+%F %T')" "$1" "$2" >> /tmp/aerospace-workspace-cycle.log 2>/dev/null || true
}

log_start

current_ws="$(aerospace list-workspaces --focused --format '%{workspace}' 2>/dev/null | head -n1 | tr -d '[:space:]')"
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

log "$base_ws" "$prev_ws"

aerospace workspace "$prev_ws"
