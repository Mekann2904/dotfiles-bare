#!/usr/bin/env bash
# plugins/wallpaper_list.sh
# wallpaper ディレクトリ内の画像をスキャンし、ポップアップに動的アイテムとプレビューを生成する。
# 簡単に壁紙を追加・選択できるように存在する。
# 関連ファイル: sketchybarrc, plugins/wallpaper.sh, plugins/wallpaper_preview.sh

set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
PLUGIN_DIR="$CONFIG_DIR/plugins"
WALLPAPER_DIR="${WALLPAPER_DIR:-$CONFIG_DIR/wallpapers}"
WALLPAPER_PARENT_ITEM="${WALLPAPER_PARENT_ITEM:-avatar}"
MAX_ITEMS="${MAX_WALLPAPER_ITEMS:-12}"
PREVIEW_DIR="${WALLPAPER_PREVIEW_DIR:-$CONFIG_DIR/cache/wallpaper_previews}"
PREVIEW_W="${WALLPAPER_PREVIEW_W:-480}"
PREVIEW_H="${WALLPAPER_PREVIEW_H:-270}"
CACHE_FILE="$CONFIG_DIR/cache/wallpaper_items.txt"

# DEBUG_LOG 環境変数があればロギング
if [ -n "${DEBUG_LOG:-}" ]; then
  DEBUG_LOG="${DEBUG_LOG:-/tmp/sketchybar_wallpaper_debug.log}"
  log_debug() { echo "$(date '+%Y-%m-%d %H:%M:%S') [LIST] $*" >> "$DEBUG_LOG"; }
else
  log_debug() { :; }
fi

mkdir -p "$WALLPAPER_DIR" "$PREVIEW_DIR"
mkdir -p "$(dirname "$CACHE_FILE")"

# 既存の動的アイテムを掃除
cleanup_items() {
  if [ -f "$CACHE_FILE" ]; then
    while IFS= read -r id; do
      [ -n "$id" ] && sketchybar --remove "$id" >/dev/null 2>&1 || true
    done < "$CACHE_FILE"
    : > "$CACHE_FILE"
  fi
}

# 指定数までアイテムを追加
add_item() {
  local idx="$1" path="$2" label="$3" preview="$4"
  local base="wallpaper.$idx"
  sketchybar --add item "$base.preview" popup."$WALLPAPER_PARENT_ITEM" \
    --set "$base.preview" \
      icon.drawing=off \
      label="" \
      background.drawing=on \
      background.image="$preview" \
      background.image.scale=1 \
      background.width=240 \
      background.height=135 \
      background.corner_radius=10 \
      background.padding_left=6 \
      background.padding_right=6 \
      background.padding_top=6 \
      background.padding_bottom=4 \
      click_script="$PLUGIN_DIR/wallpaper.sh \"$path\" $WALLPAPER_PARENT_ITEM" \
      drawing=on
  echo "$base.preview" >> "$CACHE_FILE"

  sketchybar --add item "$base" popup."$WALLPAPER_PARENT_ITEM" \
    --set "$base" \
      icon="󰸉" \
      label="$label" \
      icon.drawing=on \
      label.drawing=on \
      icon.padding_left=4 \
      icon.padding_right=6 \
      label.padding_left=2 \
      label.padding_right=6 \
      label.width=240 \
      label.align=center \
      background.drawing=off \
      click_script="$PLUGIN_DIR/wallpaper.sh \"$path\" $WALLPAPER_PARENT_ITEM" \
      drawing=on
  echo "$base" >> "$CACHE_FILE"
}

make_preview() {
  local src="$1"
  local name
  name=$(basename "$src")
  local dst="$PREVIEW_DIR/${name}.preview.png"
  if [ "$src" -nt "$dst" ]; then
    "$PLUGIN_DIR/wallpaper_preview.sh" "$src" "$dst" "$PREVIEW_W" "$PREVIEW_H"
  fi
  echo "$dst"
}

build_list() {
  cleanup_items
  local i=1
  shopt -s nullglob
  for f in "$WALLPAPER_DIR"/*.{png,jpg,jpeg,webp,heic,heif}; do
    [ "$i" -gt "$MAX_ITEMS" ] && break
    if [ -f "$f" ]; then
      local base
      base=$(basename "$f")
      local preview
      preview=$(make_preview "$f")
      add_item "$i" "$f" "$base" "$preview"
      i=$((i+1))
    fi
  done
  shopt -u nullglob

  sketchybar --add item wallpaper.close popup."$WALLPAPER_PARENT_ITEM" \
    --set wallpaper.close \
      icon="󰅖" \
      label="閉じる" \
      icon.drawing=on \
      label.drawing=on \
      icon.padding_left=4 \
      icon.padding_right=6 \
      label.padding_left=2 \
      label.padding_right=6 \
      background.drawing=off \
      click_script="sketchybar --set $WALLPAPER_PARENT_ITEM popup.drawing=off" \
      drawing=on
  echo "wallpaper.close" >> "$CACHE_FILE"
}

build_list

exit 0
