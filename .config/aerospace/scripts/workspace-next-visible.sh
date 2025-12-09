# ~/.config/aerospace/scripts/workspace-next-visible.sh
# ベースワークスペース(1〜7)のみを次に巡回する。
# 隠しワークスペースを経由しない移動を保証するために存在する。
# 関連ファイル: ~/.config/aerospace/scripts/workspace-prev-visible.sh, ~/.config/aerospace/aerospace.toml, ~/.config/aerospace/scripts/pseudo-minimize.sh, ~/.config/aerospace/scripts/pseudo-restore.sh
#!/usr/bin/env bash
set -euo pipefail

# 巡回対象のベースワークスペースを固定で持つ。
order=(1 2 3 4 5 6 7)

log_start() {
  printf '%s next start\n' "$(date '+%F %T')" >> /tmp/aerospace-workspace-cycle.log 2>/dev/null || true
}

log() {
  printf '%s next base=%s next=%s\n' "$(date '+%F %T')" "$1" "$2" >> /tmp/aerospace-workspace-cycle.log 2>/dev/null || true
}

log_start

# 現在のフォーカスWSを取得。空なら何もしない。
current_ws="$(aerospace list-workspaces --focused --format '%{workspace}' 2>/dev/null | head -n1 | tr -d '[:space:]')"
[ -n "$current_ws" ] || exit 0

# hidden サフィックスを剥がし、ベース名だけにする。
base_ws="${current_ws%-hidden}"
[ -n "$base_ws" ] || exit 0

# 現在位置のインデックスを探す。見つからなければ -1 のまま。
idx=-1
for i in "${!order[@]}"; do
  if [ "$base_ws" = "${order[$i]}" ]; then
    idx="$i"
    break
  fi
done

# 未知の名前なら先頭の 1 に飛ばす。それ以外は次を計算。
if [ "$idx" -lt 0 ]; then
  next_ws="${order[0]}"
else
  next_index=$(( (idx + 1) % ${#order[@]} ))
  next_ws="${order[$next_index]}"
fi

log "$base_ws" "$next_ws"

# フォーカス中モニタのベースWSへ移動するだけなので hidden を経由しない。
aerospace workspace "$next_ws"
