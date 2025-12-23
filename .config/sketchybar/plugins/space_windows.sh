#!/bin/bash
# plugins/space_windows.sh
# 可視ワークスペースのみを走査しアプリ名を絵文字ストリップで表示する。
# 実行コストを抑えつつワークスペース内容を即座に把握するために存在する。
# 関連ファイル: sketchybarrc, plugins/update_single_workspace.sh, plugins/icon_map_fn.sh, plugins/aerospace.sh

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"

# aeroSpaceイベントと定期ポーリングの双方から呼ばれる。
case "${SENDER:-}" in
  aerospace_workspace_change|poll|timer|routine|forced) : ;;  # 許可
  *) exit 0;;
esac

# アイコンキャッシュ（同一アプリでのフォーク回数を抑える）
cache_apps=()
cache_icons=()
icon_cached() {
  local app="$1" i
  for i in "${!cache_apps[@]}"; do
    if [ "${cache_apps[$i]}" = "$app" ]; then
      printf '%s' "${cache_icons[$i]}"
      return 0
    fi
  done
  local icon
  icon="$("$CONFIG_DIR/plugins/icon_map_fn.sh" "$app")"
  cache_apps+=("$app")
  cache_icons+=("$icon")
  printf '%s' "$icon"
}

# 区切り文字（制御文字: 通常のアプリ名には含まれない）
SEP=$'\034'

# 可視WS一覧（公式オプション構成に合わせる）
visible_workspaces="$(aerospace list-workspaces --monitor all --visible --format '%{workspace}' 2>/dev/null)"
[ -z "$visible_workspaces" ] && exit 0

# 可視WSに属するウィンドウ一覧を一括取得（WS名とアプリ名）
windows="$(aerospace list-windows --workspace visible --format '%{workspace}%{tab}%{app-name}' 2>/dev/null)"

# 可視WS順にアプリ名を連結して並べる（awk 1回で完結, WS内重複除去）
grouped="$(
  awk -F'\t' -v sep="$SEP" '
    NR==FNR { vis[$0]=1; order[++n]=$0; next }
    {
      ws=$1; app=$2
      sub(/^[[:space:]]+|[[:space:]]+$/, "", ws)
      sub(/^[[:space:]]+|[[:space:]]+$/, "", app)
      if (ws=="" || app=="" || !(ws in vis)) next
      key = ws SUBSEP app
      if (seen[key]++) next
      if (out[ws]=="") out[ws]=app; else out[ws]=out[ws] sep app
    }
    END {
      for (i=1; i<=n; i++) {
        ws=order[i]
        print ws "\t" out[ws]
      }
    }
  ' <(printf '%s\n' "$visible_workspaces") <(printf '%s\n' "$windows")
)"

# sketchybar へのコマンドを一括で組み立てる
args=()
while IFS=$'\t' read -r workspace apps_joined; do
  [ -z "$workspace" ] && continue

  args+=(--set "space.$workspace" drawing=on)

  if [ -n "$apps_joined" ]; then
    icon_strip=" "
    IFS="$SEP" read -r -a apps_arr <<<"$apps_joined"
    for app in "${apps_arr[@]}"; do
      icon_strip+=" $(icon_cached "$app")"
    done
    args+=(--set "space.$workspace" label="$icon_strip")
  else
    args+=(--set "space.$workspace" label="")
  fi
done <<<"$grouped"

[ "${#args[@]}" -gt 0 ] && sketchybar "${args[@]}"
