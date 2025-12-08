#!/bin/bash
# plugins/space_windows.sh
# 可視ワークスペースのみを走査しアプリ名を絵文字ストリップで表示する。
# 実行コストを抑えつつワークスペース内容を即座に把握するために存在する。
# 関連ファイル: sketchybarrc, plugins/update_single_workspace.sh, plugins/icon_map_fn.sh, plugins/aerospace.sh

if [ "$SENDER" = "aerospace_workspace_change" ]; then
  # 可視WSを一発で抽出（awkで厳密に判定）
  visible_workspaces="$(
    aerospace list-workspaces --format '%{id} %{workspace-is-visible}' \
    | awk '$2=="true"{print $1}'
  )"

  # 可視WSだけ更新
  for workspace in $visible_workspaces; do
    # アプリ名を明示フォーマットで取得（1行1アプリ）
    apps="$(aerospace list-windows --workspace "$workspace" --format '%{app-name}' \
      | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
      | awk 'NF' \
    )"

    sketchybar --set "space.$workspace" drawing=on

    if [ -n "$apps" ]; then
      icon_strip=" "
      # 必要なら glyph 変換、未使用ならこの while 自体を削って native アイコン路線へ
      while IFS= read -r app; do
        icon_strip+=" $("$CONFIG_DIR/plugins/icon_map_fn.sh" "$app")"
      done <<<"$apps"
      sketchybar --set "space.$workspace" label="$icon_strip"
    else
      sketchybar --set "space.$workspace" label=""
    fi
  done
fi
