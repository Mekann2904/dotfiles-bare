#!/bin/bash
# plugins/space_drag.sh
# ワークスペースのドラッグ＆ドロップによる入れ替え機能

STATE_DIR="/tmp/sketchybar_drag"
STATE_FILE="$STATE_DIR/source_space"
HOVER_FILE="$STATE_DIR/hover_space"

mkdir -p "$STATE_DIR"

# ワークスペースの入れ替え
# AeroSpaceにはワークスペース番号自体を入れ替えるコマンドがないため、
# 以下の手順で実現します：
# 1. 一時的なワークスペースを作成
# 2. ws1のウィンドウをすべて一時ワークスペースに移動
# 3. ws2のウィンドウをすべてws1に移動
# 4. 一時ワークスペースのウィンドウをすべてws2に移動
swap_workspaces() {
    local ws1="$1"
    local ws2="$2"

    # 同じワークスペースなら何もしない
    [ "$ws1" = "$ws2" ] && return 0

    # 一時的なワークスペース名を作成
    local temp_ws="_TMP_SWAP_$$"

    # 現在のフォーカスされたワークスペースを記録
    local current_ws=$(aerospace list-workspaces --focused --format '%{workspace}' 2>/dev/null)

    # ws1のウィンドウを一時ワークスペースに移動
    # aerospace list-windows --workspace "$ws1" でウィンドウを取得し、移動
    local ws1_windows=$(aerospace list-windows --workspace "$ws1" --format '%{window-id}' 2>/dev/null)
    if [ -n "$ws1_windows" ]; then
        for win_id in $ws1_windows; do
            # 一時ワークスペースを作成してフォーカス
            aerospace workspace "$temp_ws" 2>/dev/null || true
            # ウィンドウを一時ワークスペースに移動
            aerospace move-node-to-workspace --window-id "$win_id" "$temp_ws" 2>/dev/null || true
        done
    fi

    # ws2のウィンドウをws1に移動
    local ws2_windows=$(aerospace list-windows --workspace "$ws2" --format '%{window-id}' 2>/dev/null)
    if [ -n "$ws2_windows" ]; then
        for win_id in $ws2_windows; do
            aerospace move-node-to-workspace --window-id "$win_id" "$ws1" 2>/dev/null || true
        done
    fi

    # 一時ワークスペースのウィンドウをws2に移動
    local temp_windows=$(aerospace list-windows --workspace "$temp_ws" --format '%{window-id}' 2>/dev/null)
    if [ -n "$temp_windows" ]; then
        for win_id in $temp_windows; do
            aerospace move-node-to-workspace --window-id "$win_id" "$ws2" 2>/dev/null || true
        done
    fi

    # 一時ワークスペースを削除（空になったら自動的に消えるはず）

    # 元のフォーカス位置に戻る（可能なら）
    if [ -n "$current_ws" ]; then
        aerospace workspace "$current_ws" 2>/dev/null || true
    fi

    # SketchyBarを更新
    sketchybar --trigger aerospace_workspace_change
}

# ドラッグ開始
start_drag() {
    local space="$1"
    local space_id="${space#space.}"

    # ドラッグ状態を保存
    echo "$space" > "$STATE_FILE"
    # ソースを赤でハイライト
    sketchybar --set "$space" icon.color=0xFFFF0000

    logger "Started dragging workspace: $space_id"
}

# ドラッグ終了
end_drag() {
    local target_space="$1"

    if [ -f "$STATE_FILE" ]; then
        local source_space=$(cat "$STATE_FILE")
        local source_id="${source_space#space.}"
        local target_id="${target_space#space.}"

        # ソースとターゲットが異なる場合のみ入れ替え
        if [ "$source_id" != "$target_id" ] && [ -n "$target_id" ]; then
            logger "Swapping workspace $source_id with $target_id"
            swap_workspaces "$source_id" "$target_id"
        fi
    fi

    # 状態ファイルを削除
    rm -f "$STATE_FILE"
    rm -f "$HOVER_FILE"

    # 色をリセット
    reset_colors
}

# 色のリセット
reset_colors() {
    local max_workspaces=${WORKSPACE_RANGE_MAX:-7}

    for sid in $(seq 1 $max_workspaces); do
        sketchybar --set "space.$sid" icon.color=0xffffffff
    done
    sketchybar --set "space.T" icon.color=0xffffffff 2>/dev/null || true
    sketchybar --set "space.D" icon.color=0xffffffff 2>/dev/null || true
}

# マウスエンター（ドラッグ中に他のワークスペースに入った）
handle_mouse_entered() {
    local target_space="$1"
    local target_id="${target_space#space.}"

    # ドラッグ中かチェック
    if [ -f "$STATE_FILE" ]; then
        local source_space=$(cat "$STATE_FILE")
        local source_id="${source_space#space.}"

        # ソースとターゲットが異なる場合のみハイライト
        if [ "$source_id" != "$target_id" ]; then
            echo "$target_space" > "$HOVER_FILE"
            # ターゲットを黄色でハイライト
            sketchybar --set "$target_space" icon.color=0xFFFFFF00
        fi
    fi
}

# マウスイグジット（ワークスペースから出た）
handle_mouse_exited() {
    local space_name="$1"
    local space_id="${space_name#space.}"

    # ドラッグ中かチェック
    if [ -f "$STATE_FILE" ]; then
        local source_space=$(cat "$STATE_FILE")
        local source_id="${source_space#space.}"

        # ソースと異なるワークスペースなら色をリセット
        if [ "$source_id" != "$space_id" ]; then
            sketchybar --set "$space_name" icon.color=0xffffffff
        fi
    fi

    # ホバー状態をクリア
    if [ -f "$HOVER_FILE" ]; then
        local hover_space=$(cat "$HOVER_FILE")
        if [ "$hover_space" = "$space_name" ]; then
            rm -f "$HOVER_FILE"
        fi
    fi
}

# メイン処理
MODE="$1"
shift

case "$MODE" in
    click)
        space_name="$1"
        space_id="${space_name#space.}"

        # ドラッグ中かチェック
        if [ -f "$STATE_FILE" ]; then
            # ドラッグ中ならドロップ処理
            end_drag "$space_name"
        else
            # ドラッグ中でなければ、ワークスペース移動してドラッグ開始
            aerospace workspace "$space_id" 2>/dev/null || true
            start_drag "$space_name"
        fi
        ;;
    mouse.entered|mouse.exited)
        space_name="$1"
        if [ "$MODE" = "mouse.entered" ]; then
            handle_mouse_entered "$space_name"
        else
            handle_mouse_exited "$space_name"
        fi
        ;;
    *)
        # SketchyBarからのイベント呼び出し
        # NAME環境変数にアイテム名が含まれる
        if [ -n "$NAME" ]; then
            # $SENDER にイベントタイプが含まれる（SketchyBarの環境変数）
            case "$SENDER" in
                mouse.entered)
                    handle_mouse_entered "$NAME"
                    ;;
                mouse.exited)
                    handle_mouse_exited "$NAME"
                    ;;
            esac
        fi
        ;;
esac
