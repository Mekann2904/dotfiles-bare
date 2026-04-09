#!/usr/bin/env bash
# plugins/update_single_workspace.sh
# ワークスペース群の見た目をまとめて描画する高速レンダラー。
# 同じスナップショットからフォーカス装飾・アプリアイコン・hidden表示を揃えて更新するために存在する。
# 関連ファイル: sketchybarrc, plugins/workspace_events.sh, plugins/hidden_windows.sh

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
SKETCHYBAR_BIN="${BAR_NAME:-sketchybar}"
HIDDEN_RESTORE_SCRIPT="$CONFIG_DIR/plugins/hidden_windows.sh"

# フェイルセーフ: 空スナップショット時は即終了し、呼び出し元が再試行する
if [ -z "${WINDOW_SNAPSHOT:-}" ]; then
  WINDOW_SNAPSHOT=""
fi

# 許可イベント以外は静かに終了
case "${SENDER:-}" in
  ""|poll|timer|routine|forced)
    ;;  # ポーリングや手動実行を許可
  delayed|workspace_manual_change|workspace_content_change|aerospace_workspace_change|window_created|window_destroyed|application_launched|application_terminated|front_app_switched|window_focused)
    ;;  # イベント実行も許可
  *)
    exit 0
    ;;
esac

# デバッグログ（必要時のみ）
if [ -n "$DEBUG_LOG" ]; then
  DEBUG_LOG="${DEBUG_LOG:-/tmp/sketchybar_fast_update.log}"
  log_debug() { printf '%s [FAST_UPDATE] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$DEBUG_LOG"; }
else
  log_debug() { :; }
fi

# パフォーマンス計測（ms単位、bc非依存）
if [ -n "$PERF_LOG" ]; then
  PERF_LOG="${PERF_LOG:-/tmp/sketchybar_perf.log}"
  now_ms() { perl -MTime::HiRes -e 'printf "%.0f", Time::HiRes::time()*1000'; }
  perf_start() { now_ms; }
  perf_end() {
    local op="$1" start="$2" end dur
    end="$(now_ms)"
    dur=$(( end - start ))
    printf '%s [PERF] %s took %sms\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$op" "$dur" >>"$PERF_LOG"
  }
else
  perf_start() { :; }
  perf_end() { :; }
fi

# 設定値
DEFAULT_MIN_WORKSPACE=1
DEFAULT_MAX_WORKSPACE=7
MIN_WORKSPACE=${MIN_WORKSPACE:-$DEFAULT_MIN_WORKSPACE}
MAX_WORKSPACE=${WORKSPACE_RANGE_MAX:-${MAX_WORKSPACE:-$DEFAULT_MAX_WORKSPACE}}
EXTRA_WORKSPACES="${EXTRA_WORKSPACES:-T D}"

VISIBLE_ICON_SLOTS=${VISIBLE_ICON_SLOTS:-4}
ICON_WIDTH=${ICON_WIDTH:-16}
ICON_HEIGHT=${ICON_HEIGHT:-16}
ICON_ITEM_WIDTH=${ICON_ITEM_WIDTH:-24}
ICON_IMAGE_SCALE=${ICON_IMAGE_SCALE:-0.8}
HIDDEN_ICON_SLOTS=${HIDDEN_ICON_SLOTS:-4}
HIDDEN_ICON_SCALE=${HIDDEN_ICON_SCALE:-0.8}
HIDDEN_ICON_BG_HEIGHT=${HIDDEN_ICON_BG_HEIGHT:-16}
HIDDEN_ITEM_WIDTH=${HIDDEN_ITEM_WIDTH:-24}

FOCUSED_WORKSPACE="${FOCUSED_WORKSPACE:-}"
HIDDEN_BASE_WORKSPACE="${HIDDEN_BASE_WORKSPACE:-}"
HIDDEN_SNAPSHOT="${HIDDEN_SNAPSHOT:-}"
WORKSPACE_RENDER_MODE="${WORKSPACE_RENDER_MODE:-full}"
CMD=()

# 区切り文字（アプリ名には通常含まれない制御文字）
SEP=$'\034'

trim() {
  local v="$1"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  printf '%s' "$v"
}

normalize_ws() {
  local s; s="$(trim "$1")"
  [ -n "$s" ] || return 1
  printf '%s\n' "$s"
}

is_supported_ws() {
  local ws="$1"
  case "$ws" in
    '' ) return 1 ;;
    *[!0-9]* ) ;;
    * )
      [ "$ws" -ge "$MIN_WORKSPACE" ] && [ "$ws" -le "$MAX_WORKSPACE" ]
      return $? ;;
  esac

  local extra
  for extra in $EXTRA_WORKSPACES; do
    [ "$ws" = "$extra" ] && return 0
  done
  return 1
}

workspace_list() {
  local list=()
  local i
  for ((i=MIN_WORKSPACE; i<=MAX_WORKSPACE; i++)); do
    list+=("$i")
  done
  for i in $EXTRA_WORKSPACES; do
    list+=("$i")
  done
  printf '%s\n' "${list[@]}"
}

parse_info_tokens() {
  [ -n "${INFO:-}" ] || return 0
  printf '%s' "$INFO" | tr -c '[:alnum:]' ' ' | awk '{for(i=1;i<=NF;i++)print $i}'
}

update_workspace_icons() {
  local workspace="$1" total_count="$2" apps_joined="$3"
  local t0; t0="$(perf_start)"

  log_debug "Updating ws=$workspace total=$total_count"

  CMD+=(--set "space.$workspace" drawing=on icon="$workspace" icon.drawing=on)

  local apps_arr=() shown=0
  if [ -n "$apps_joined" ]; then
    IFS="$SEP" read -r -a apps_arr <<<"$apps_joined"
    shown=${#apps_arr[@]}
  fi

  local extra_count=0
  if [ "$total_count" -gt "$shown" ]; then
    extra_count=$(( total_count - shown ))
  fi

  local slot=1
  while [ "$slot" -le "$VISIBLE_ICON_SLOTS" ]; do
    local item="space.$workspace.icon$slot"
    if [ "$slot" -le "$shown" ]; then
      local app="${apps_arr[$((slot-1))]}"
      CMD+=(--set "$item"
        drawing=on
        width="$ICON_ITEM_WIDTH"
        icon=" "
        icon.drawing=on
        "icon.background.image=app.$app"
        icon.background.drawing=on
        "icon.background.image.scale=$ICON_IMAGE_SCALE"
        icon.background.corner_radius=3
        "icon.background.height=$ICON_HEIGHT"
        icon.background.y_offset=0
        icon.padding_left=2
        icon.padding_right=2
        "icon.width=$ICON_WIDTH"
        label=""
        label.drawing=off
      )
    else
      CMD+=(--set "$item"
        drawing=off
        width=0
        padding_left=0
        padding_right=0
        icon=""
        icon.drawing=off
        icon.background.drawing=off
      )
    fi
    slot=$((slot + 1))
  done

  if [ "$extra_count" -gt 0 ]; then
    CMD+=(--set "space.$workspace.more"
      drawing=on
      width="$ICON_ITEM_WIDTH"
      icon.drawing=off
      "label=+$extra_count"
      label.drawing=on
      label.padding_left=2
      label.padding_right=2
    )
  else
    CMD+=(--set "space.$workspace.more"
      drawing=off
      width=0
      padding_left=0
      padding_right=0
      label=""
      label.drawing=off
    )
  fi

  perf_end "update_workspace_$workspace" "$t0"
}

apply_focus_state() {
  local ws
  for ws in $(workspace_list); do
    if [ "$ws" = "$FOCUSED_WORKSPACE" ]; then
      CMD+=(--set "space.$ws"
        icon.color=0xFFFFFFFF
        icon.font="Hack Nerd Font:Bold:16.0"
        background.drawing=off
      )
      CMD+=(--set "space.$ws.underline"
        drawing=on
        background.drawing=on
      )
    else
      CMD+=(--set "space.$ws"
        icon.color=0x88FFFFFF
        icon.font="Hack Nerd Font:Semibold:16.0"
        background.drawing=off
      )
      CMD+=(--set "space.$ws.underline"
        drawing=off
        background.drawing=off
      )
    fi
  done
}

apply_hidden_state() {
  local hidden_ws hidden_entries hidden_count slot win_id app_name item

  if [ -z "$HIDDEN_BASE_WORKSPACE" ]; then
    CMD+=(--set hidden drawing=off icon.drawing=off label="" label.drawing=off)
    for slot in $(seq 1 "$HIDDEN_ICON_SLOTS"); do
      CMD+=(--set "hidden.icon${slot}"
        drawing=off
        width=0
        icon.drawing=off
        background.drawing=off
        click_script=""
      )
    done
    return 0
  fi

  if [ -n "$HIDDEN_SNAPSHOT" ]; then
    hidden_entries="$HIDDEN_SNAPSHOT"
  else
    hidden_ws="${HIDDEN_BASE_WORKSPACE}-hidden"
    hidden_entries="$(
      printf '%s\n' "$windows" | awk -F'\t' -v target="$hidden_ws" '
        {
          ws=$1
          win_id=$2
          app=$3
          sub(/^[[:space:]]+/, "", ws);     sub(/[[:space:]]+$/, "", ws)
          sub(/^[[:space:]]+/, "", win_id); sub(/[[:space:]]+$/, "", win_id)
          sub(/^[[:space:]]+/, "", app);    sub(/[[:space:]]+$/, "", app)
          if (ws != target || win_id == "" || app == "") next
          print win_id "\t" app
        }
      '
    )"
  fi

  hidden_count=$(printf '%s\n' "$hidden_entries" | awk 'NF { count++ } END { print count + 0 }')
  CMD+=(--set hidden drawing=off icon.drawing=off label="" label.drawing=off)

  if [ "$hidden_count" -eq 0 ]; then
    for slot in $(seq 1 "$HIDDEN_ICON_SLOTS"); do
      CMD+=(--set "hidden.icon${slot}"
        drawing=off
        width=0
        icon.drawing=off
        background.drawing=off
        click_script=""
      )
    done
    return 0
  fi

  slot=1
  while IFS=$'\t' read -r win_id app_name; do
    [ -n "$win_id" ] || continue
    [ -n "$app_name" ] || continue
    [ "$slot" -le "$HIDDEN_ICON_SLOTS" ] || break

    item="hidden.icon${slot}"
    CMD+=(--set "$item"
      drawing=on
      width="$HIDDEN_ITEM_WIDTH"
      icon.drawing=off
      label.drawing=off
      "background.image=app.$app_name"
      background.drawing=on
      "background.image.scale=$HIDDEN_ICON_SCALE"
      "background.height=$HIDDEN_ICON_BG_HEIGHT"
      background.corner_radius=3
      background.y_offset=0
      padding_left=0
      padding_right=0
      "click_script=$HIDDEN_RESTORE_SCRIPT restore $win_id"
    )
    slot=$((slot + 1))
  done <<<"$hidden_entries"

  while [ "$slot" -le "$HIDDEN_ICON_SLOTS" ]; do
    CMD+=(--set "hidden.icon${slot}"
      drawing=off
      width=0
      icon.drawing=off
      background.drawing=off
      click_script=""
    )
    slot=$((slot + 1))
  done
}

main() {
  command -v aerospace >/dev/null 2>&1 || { log_debug "aerospace not found"; return 0; }

  local inputs=()
  if [ "$#" -gt 0 ]; then
    inputs=("$@")
  elif [ -n "$INFO" ]; then
    mapfile -t inputs < <(parse_info_tokens)
  fi

  local targets=()
  if [ "${#inputs[@]}" -gt 0 ]; then
    local arg ws
    for arg in "${inputs[@]}"; do
      ws="$(normalize_ws "$arg")" || { log_debug "Invalid workspace input: $arg"; continue; }
      if is_supported_ws "$ws"; then
        case " ${targets[*]} " in *" $ws "*) : ;; *) targets+=("$ws");; esac
      else
        log_debug "Workspace $ws out of range ($MIN_WORKSPACE-$MAX_WORKSPACE)"
      fi
    done
  fi

  local windows

  CMD=("$SKETCHYBAR_BIN")
  apply_focus_state

  if [ "$WORKSPACE_RENDER_MODE" != "focus-only" ]; then
    local ws_list=()
    if [ "${#targets[@]}" -gt 0 ]; then
      ws_list=("${targets[@]}")
    else
      mapfile -t ws_list < <(workspace_list)
    fi

    if [ -n "${WINDOW_SNAPSHOT:-}" ]; then
      windows="$WINDOW_SNAPSHOT"
      log_debug "Using provided snapshot (${#ws_list[@]} workspaces)"
    else
      windows="$(aerospace list-windows --all --format '%{workspace}%{tab}%{window-id}%{tab}%{app-name}' 2>/dev/null)" || windows=""
      [ -n "$windows" ] || log_debug "Empty snapshot; rendering empty state"
    fi

    local grouped
    grouped="$(
      awk -F'\t' -v sep="$SEP" -v slots="$VISIBLE_ICON_SLOTS" '
        NR==FNR { order[++n]=$0; want[$0]=1; next }
        {
          ws=$1; app=$3
          sub(/^[[:space:]]+/, "", ws);  sub(/[[:space:]]+$/, "", ws)
          sub(/^[[:space:]]+/, "", app); sub(/[[:space:]]+$/, "", app)
          if (ws=="" || app=="" || !(ws in want)) next

          key = ws SUBSEP app
          if (seen[key]++) next

          cnt[ws]++
          if (lstn[ws] < slots) {
            lstn[ws]++
            if (lst[ws]=="") lst[ws]=app
            else lst[ws]=lst[ws] sep app
          }
        }
        END {
          for (i=1; i<=n; i++) {
            ws=order[i]
            c=(ws in cnt)?cnt[ws]:0
            print ws "\t" c "\t" lst[ws]
          }
        }
      ' <(printf '%s\n' "${ws_list[@]}") <(printf '%s\n' "$windows")
    )"

    local line ws count list
    while IFS=$'\t' read -r ws count list; do
      [ -n "$ws" ] || continue
      update_workspace_icons "$ws" "${count:-0}" "$list"
    done <<<"$grouped"
  fi

  apply_hidden_state

  [ "${#CMD[@]}" -gt 1 ] && "${CMD[@]}" >/dev/null 2>&1 || true

  return 0
}

main "$@" || true
exit 0
