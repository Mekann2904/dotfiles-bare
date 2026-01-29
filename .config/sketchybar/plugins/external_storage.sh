#!/usr/bin/env bash
# plugins/external_storage.sh
# 外部ストレージの温度を取得し、バーとポップアップに表示する。
# クリックで確認ダイアログを出し、安全に取り外すボタンを提供するために存在する。
# 関連ファイル: sketchybarrc, plugins/ram_min.sh, plugins/network.sh, plugins/battery.sh

set -u

PLUGIN_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}/plugins"
NAME_BASE="${NAME:-disk}"
MAX_ITEMS=4
TIMEOUT_SEC=2

# コマンドのパス解決
SMARTCTL_BIN="${SMARTCTL_BIN:-$(command -v smartctl || true)}"
DISKUTIL_BIN="${DISKUTIL_BIN:-/usr/sbin/diskutil}"

log_debug() {
  [ -z "${DEBUG_LOG:-}" ] && return 0
  echo "$(date '+%Y-%m-%d %H:%M:%S') [DISK] $*" >> "${DEBUG_LOG}"
}

run_with_timeout() {
  # perlで簡易timeout。指定秒を超えたらプロセスをkill。
  perl -e 'alarm shift; exec @ARGV' "$TIMEOUT_SEC" "$@"
}

extract_temperature() {
  local disk_id="$1"
  local temp="--°C"
  local raw=""

  [ -z "$SMARTCTL_BIN" ] && echo "$temp" && return

  # 1. 権限があればそのまま
  if [ -z "$raw" ]; then
    raw=$(run_with_timeout "$SMARTCTL_BIN" -A "$disk_id" 2>/dev/null | \
      grep -Ei "Temperature_Celsius|Temperature Sensor|Current Drive Temperature|Temperature" | \
      head -1 | grep -Eo "[0-9]{2,3}" | head -1)
  fi

  # 2. sudo -n + sat (一般的なUSB-SATAケース)
  if [ -z "$raw" ]; then
    raw=$(run_with_timeout sudo -n "$SMARTCTL_BIN" -A -d sat "$disk_id" 2>/dev/null | \
      grep -Ei "Temperature_Celsius|Temperature Sensor|Current Drive Temperature|Temperature" | \
      head -1 | grep -Eo "[0-9]{2,3}" | head -1)
  fi

  # 3. sudo -n + nvme (NVMeケース)
  if [ -z "$raw" ]; then
    raw=$(run_with_timeout sudo -n "$SMARTCTL_BIN" -A -d nvme "$disk_id" 2>/dev/null | \
      grep -Ei "Temperature_Celsius|Temperature Sensor|Current Drive Temperature|Temperature" | \
      head -1 | grep -Eo "[0-9]{2,3}" | head -1)
  fi

  if [ -n "$raw" ]; then
    echo "${raw}°C"
  else
    echo "$temp"
  fi
}

escape_for_applescript() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

escape_for_shell() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\$/\\$/g' -e 's/`/\\`/g'
}

confirm_and_eject() {
  local disk_id="$1"
  local disk_name="$2"
  local escaped_name
  escaped_name=$(escape_for_applescript "$disk_name")

  log_debug "Eject requested: $disk_id ($disk_name)"

  local result
  result=$(osascript <<EOF
set dialogText to "${escaped_name} を取り外しますか？"
display dialog dialogText buttons {"キャンセル", "取り外す"} default button "取り外す" with icon caution
return button returned of the result
EOF
  )

  [ "$result" != "取り外す" ] && return

  if "$DISKUTIL_BIN" eject "$disk_id" >/dev/null 2>&1; then
    osascript -e "display notification \"${escaped_name} を取り外しました\" with title \"Disk Ejected\""
    sketchybar --set "$NAME_BASE" popup.drawing=off
    sketchybar --trigger volume_change
  else
    osascript -e "display dialog \"${escaped_name} を取り外せませんでした。使用中のアプリを確認してください。\" buttons {\"OK\"} default button \"OK\" with icon stop"
  fi
}

list_external_disks() {
  # 物理ディスクのみリストアップ
  "$DISKUTIL_BIN" list external physical 2>/dev/null | awk '/^\/dev\/disk/ {print $1}'
}

build_entries() {
  local entries=()

  while read -r disk; do
    [ -z "$disk" ] && continue
    [ ${#entries[@]} -ge $MAX_ITEMS ] && break

    local info
    info=$("$DISKUTIL_BIN" info "$disk")

    local name
    name=$(echo "$info" | awk -F': *' '/Media Name/ {print $2; exit}')
    [ -z "$name" ] && name=$(echo "$info" | awk -F': *' '/Volume Name/ {print $2; exit}')
    [ -z "$name" ] && name="$disk"

    local temp
    temp=$(extract_temperature "$disk")

    # マウント状態はラベルから除外するため空文字を格納
    entries+=("${disk}|${name}|${temp}|")
  done < <(list_external_disks)

  if [ ${#entries[@]} -eq 0 ]; then
    sketchybar --set "$NAME_BASE" drawing=off
    for i in $(seq 1 $MAX_ITEMS); do
      sketchybar --set "${NAME_BASE}.entry${i}" drawing=off
    done
    return
  fi

  IFS='|' read -r _ _ first_temp _ <<< "${entries[0]}"
  sketchybar --set "$NAME_BASE" \
    label="${first_temp}" \
    icon="󰋊" \
    drawing=on

  local idx=1
  for entry in "${entries[@]}"; do
    IFS='|' read -r edisk ename etemp emount <<< "$entry"

    local label
    label="$ename $etemp"

    local escaped_name
    escaped_name=$(escape_for_shell "$ename")
    sketchybar --set "${NAME_BASE}.entry${idx}" \
      icon="󱘟" \
      label="$label" \
      click_script="sketchybar --set $NAME_BASE popup.drawing=off; $PLUGIN_DIR/external_storage.sh eject $edisk \"$escaped_name\"" \
      drawing=on
    idx=$((idx + 1))
  done

  while [ $idx -le $MAX_ITEMS ]; do
    sketchybar --set "${NAME_BASE}.entry${idx}" drawing=off
    idx=$((idx + 1))
  done
}

case "${1:-update}" in
  eject)
    confirm_and_eject "$2" "${3:-Device}"
    ;;
  *)
    build_entries
    ;;
esac
