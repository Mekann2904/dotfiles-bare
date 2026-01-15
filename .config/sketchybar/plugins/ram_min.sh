#!/usr/bin/env bash
# plugins/ram_min.sh
# メモリ使用率を最小限の情報で計算しラベル更新する。
# 外部コマンド失敗時でも落とさずバーを汚さないために存在する。
# 関連ファイル: sketchybarrc, plugins/battery.sh, plugins/network.sh, plugins/volume.sh

# ラベルだけ更新。外部コマンドが空でも落ちない。

# デバッグログ設定（DEBUG_LOGが設定されている場合のみ有効）
if [ -n "$DEBUG_LOG" ]; then
  DEBUG_LOG="${DEBUG_LOG:-/tmp/sketchybar_ram_debug.log}"
  log_debug() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [RAM] $*" >> "$DEBUG_LOG"
  }
else
  log_debug() { :; }  # 何もしない
fi

log_debug "Starting RAM calculation"

pagesize="$(/usr/sbin/sysctl -n hw.pagesize 2>/dev/null || echo 4096)"
total_bytes="$(/usr/sbin/sysctl -n hw.memsize 2>/dev/null || echo 0)"

log_debug "Page size: $pagesize, Total bytes: $total_bytes"

vm="$(/usr/bin/vm_stat 2>/dev/null || true)"
get_pages() {
  echo "$vm" | /usr/bin/awk -v pat="$1" -v f="${2:-3}" '
    $0 ~ pat { gsub("\\.","",$f); print $f; exit }
  '
}

free=$(get_pages "Pages free")
inactive=$(get_pages "Pages inactive")
speculative=$(get_pages "Pages speculative")
[ -z "$free" ] && free=0
[ -z "$inactive" ] && inactive=0
[ -z "$speculative" ] && speculative=0

log_debug "Free pages: $free, Inactive: $inactive, Speculative: $speculative"

if [ "$total_bytes" -gt 0 ]; then
  total_pages=$(( total_bytes / pagesize ))
else
  total_pages=1
fi
available=$(( free + inactive + speculative ))
used=$(( total_pages - available ))
pct=$(( used * 100 / total_pages ))

log_debug "Total pages: $total_pages, Available: $available, Used: $used, Percentage: $pct%"

to_gb() { /usr/bin/awk -v b="$1" 'BEGIN{printf "%.1f", b/1024/1024/1024}'; }
used_bytes=$((used * pagesize))
used_gb="$(to_gb "$used_bytes")"
total_gb="$(to_gb "$total_bytes")"

log_debug "Used GB: $used_gb, Total GB: $total_gb"

# 色は白だけ
log_debug "Color set to white (percentage: $pct%)"

# ここが切れてた。ちゃんと pct を使う
sketchybar --set "${NAME:-ram}" \
  label="${pct}%"

log_debug "RAM update completed: ${pct}%"
