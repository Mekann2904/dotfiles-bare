#!/usr/bin/env bash
# plugins/update_single_workspace.sh
# シンプルで高速なワークスペースアイコン更新スクリプト
# ロック機構を排除し、対象ワークスペースのみを更新することで高速化
# 関連ファイル: sketchybarrc, plugins/workspace_events.sh

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"

# デバッグログ設定（DEBUG_LOGが設定されている場合のみ有効）
if [ -n "$DEBUG_LOG" ]; then
  DEBUG_LOG="${DEBUG_LOG:-/tmp/sketchybar_fast_update.log}"
  log_debug() {
    echo "$(date '+%Y-%m-%d %H:%M:%S.%3N') [FAST_UPDATE] $*" >> "$DEBUG_LOG"
  }
else
  log_debug() { :; }  # 何もしない
fi

# パフォーマンス計測（PERF_LOGが設定されている場合のみ有効）
if [ -n "$PERF_LOG" ]; then
  PERF_LOG="${PERF_LOG:-/tmp/sketchybar_perf.log}"
  perf_start() {
    START_TIME=$(date +%s.%3N)
  }
  perf_end() {
    local operation="$1"
    local end_time=$(date +%s.%3N)
    local duration=$(echo "$end_time - $START_TIME" | bc -l)
    echo "$(date '+%Y-%m-%d %H:%M:%S') [PERF] $operation took ${duration}s" >> "$PERF_LOG"
  }
else
  perf_start() { :; }
  perf_end() { :; }
fi

# 設定値（WORKSPACE_RANGE_MAXを9にすれば即座に1-9へ戻せる）
DEFAULT_MIN_WORKSPACE=1
DEFAULT_MAX_WORKSPACE=7
MIN_WORKSPACE=${MIN_WORKSPACE:-$DEFAULT_MIN_WORKSPACE}
MAX_WORKSPACE=${WORKSPACE_RANGE_MAX:-${MAX_WORKSPACE:-$DEFAULT_MAX_WORKSPACE}}
VISIBLE_ICON_SLOTS=${VISIBLE_ICON_SLOTS:-4}
ICON_WIDTH=${ICON_WIDTH:-16}
ICON_HEIGHT=${ICON_HEIGHT:-16}
ICON_ITEM_WIDTH=${ICON_ITEM_WIDTH:-24}
ICON_IMAGE_SCALE=${ICON_IMAGE_SCALE:-0.8}

# ワークスペース番号の正規化と検証
normalize_ws() {
  local s="$1"
  # 数字のみを抽出
  local d="${s//[!0-9]/}"
  [ -n "$d" ] || return 1
  printf '%s\n' "$d"
}

is_supported_ws() {
  case "$1" in ''|*[!0-9]*) return 1;; esac
  [ "$1" -ge "$MIN_WORKSPACE" ] && [ "$1" -le "$MAX_WORKSPACE" ]
}

# 高速なウィンドウ情報収集（キャッシュなし、エラー耐性強化）
collect_windows_fast() {
  local workspace="$1"
  
  if ! command -v aerospace >/dev/null 2>&1; then
    log_debug "aerospace command not found"
    echo ""  # 空の出力を返して続行
    return 0
  fi

  local output
  if [ -n "$workspace" ]; then
    # 特定のワークスペースのみ取得
    if ! output=$(aerospace list-windows --workspace "$workspace" --format '%{app-name}' 2>/dev/null); then
      log_debug "aerospace command failed for workspace $workspace"
      echo ""  # 空の出力を返して続行
      return 0
    fi
  else
    # 全ワークスペースを取得（--allオプション必須）
    if ! output=$(aerospace list-windows --all --format '%{workspace}|%{app-name}' 2>/dev/null); then
      log_debug "aerospace command failed for all workspaces"
      echo ""  # 空の出力を返して続行
      return 0
    fi
  fi
  
  echo "$output"
}

# アプリケーション名の重複排除と順序保持
get_unique_apps() {
  awk '!seen[$0]++' | head -"$VISIBLE_ICON_SLOTS"
}

# バッチ化されたSketchyBarコマンドの構築と実行
update_workspace_icons() {
  local workspace="$1"
  local apps="$2"
  
  perf_start
  log_debug "Updating workspace $workspace with apps: $(echo "$apps" | tr '\n' ' ')"
  
  # コマンド配列の構築
  local cmd=(sketchybar)
  
  # ワークスペースアイテムの基本設定
  cmd+=(--set "space.$workspace" drawing=on icon="$workspace" icon.drawing=on)
  
  # アプリケーションアイコンの設定
  local slot=1
  local extra_count=0
  local app_count=0
  
  if [ -n "$apps" ]; then
    app_count=$(echo "$apps" | grep -c . || true)
    extra_count=$((app_count > VISIBLE_ICON_SLOTS ? app_count - VISIBLE_ICON_SLOTS : 0))
    
    # 表示するアプリケーションの処理
    while IFS= read -r app && [ "$slot" -le "$VISIBLE_ICON_SLOTS" ]; do
      local item="space.$workspace.icon$slot"
      local escaped_app=$(printf '%s' "$app" | sed -e 's/[\\"]/\\&/g')
      
      cmd+=(--set "$item"
        drawing=on
        width="$ICON_ITEM_WIDTH"
        icon=" "
        icon.drawing=on
        icon.background.image="app.$escaped_app"
        icon.background.drawing=on
        icon.background.image.scale="$ICON_IMAGE_SCALE"
        icon.background.corner_radius=3
        icon.background.height="$ICON_HEIGHT"
        icon.background.y_offset=0
        icon.padding_left=2
        icon.padding_right=2
        icon.width="$ICON_WIDTH"
        label=""
        label.drawing=off
      )
      slot=$((slot + 1))
    done <<< "$(echo "$apps" | head -"$VISIBLE_ICON_SLOTS")"
  fi
  
  # 残りのスロットを非表示に設定
  while [ "$slot" -le "$VISIBLE_ICON_SLOTS" ]; do
    local item="space.$workspace.icon$slot"
    # drawing=off だけだと幅が残り、ブランケットの左右余白が崩れるので width=0 に寄せる。
    cmd+=(--set "$item"
      drawing=off
      width=0
      padding_left=0
      padding_right=0
      icon=""
      icon.drawing=off
      icon.background.drawing=off
    )
    slot=$((slot + 1))
  done
  
  # 追加アプリケーション数の表示
  if [ "$extra_count" -gt 0 ]; then
    cmd+=(--set "space.$workspace.more"
      drawing=on
      width="$ICON_ITEM_WIDTH"
      icon.drawing=off
      label="+$extra_count"
      label.drawing=on
      label.padding_left=2
      label.padding_right=2
    )
  else
    cmd+=(--set "space.$workspace.more"
      drawing=off
      width=0
      padding_left=0
      padding_right=0
      label=""
      label.drawing=off
    )
  fi
  
  # バッチコマンドの実行
  log_debug "Executing batch command for workspace $workspace"
  "${cmd[@]}"
  perf_end "update_workspace_$workspace"
}

# メイン処理
main() {
  local inputs=("$@")
  local targets=()
  
  log_debug "Script started with targets: ${inputs[*]:-all}"
  perf_start
  
  # 引数があればすべて正規化して採用。無効値はスキップ。
  if [ "${#inputs[@]}" -gt 0 ]; then
    for arg in "${inputs[@]}"; do
      local ws
      ws=$(normalize_ws "$arg") || {
        log_debug "Invalid workspace input: $arg"
        continue
      }
      if is_supported_ws "$ws"; then
        # 重複を排除
        case " ${targets[*]} " in
          *" $ws "*) ;; 
          *) targets+=("$ws");;
        esac
      else
        log_debug "Workspace $ws not in supported range ($MIN_WORKSPACE-$MAX_WORKSPACE)"
      fi
    done
  fi
  
  if [ "${#targets[@]}" -gt 0 ]; then
    log_debug "Processing targeted workspaces: ${targets[*]}"
    for ws in "${targets[@]}"; do
      local apps
      apps=$(collect_windows_fast "$ws" | get_unique_apps)
      update_workspace_icons "$ws" "$apps"
    done
  else
    # 引数が無いか全て無効だった場合は全ワークスペース更新
    log_debug "Processing all workspaces"
    local all_data
    all_data=$(collect_windows_fast "")
    
    for ws in $(seq "$MIN_WORKSPACE" "$MAX_WORKSPACE"); do
      local apps_for_ws
      apps_for_ws=$(echo "$all_data" | awk -F'|' -v id="$ws" '$1 == id {print $2}' | get_unique_apps)
      update_workspace_icons "$ws" "$apps_for_ws"
    done
  fi
  
  perf_end "total_script_execution"
  log_debug "Script completed successfully"
  return 0  # 常に成功を返す
}

# スクリプトの実行
if [ "$#" -gt 0 ]; then
  main "$@"
elif [ -n "$INFO" ]; then
  main "$INFO"
else
  main
fi
