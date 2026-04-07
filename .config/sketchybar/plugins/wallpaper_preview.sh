#!/usr/bin/env bash
# plugins/wallpaper_preview.sh
# 壁紙画像から固定サイズのプレビューPNGを生成するユーティリティ。
# プレビューの表示サイズを統一し、ポップアップの見栄えを揃えるために存在する。
# 関連ファイル: sketchybarrc, plugins/wallpaper.sh, plugins/user.png

SRC="$1"
DST="$2"
WIDTH="${3:-300}"
HEIGHT="${4:-180}"

if [ -z "$SRC" ] || [ -z "$DST" ]; then
  exit 1
fi

if [ ! -f "$SRC" ]; then
  exit 1
fi

dst_dir="$(dirname "$DST")"
mkdir -p "$dst_dir"

# 縦横比は維持しつつ、固定サイズのキャンバス中央に収める。
# まずは ImageMagick を優先し、無ければ sips の縮小だけでフォールバックする。
if command -v magick >/dev/null 2>&1; then
  magick "$SRC" \
    -resize "${WIDTH}x${HEIGHT}" \
    -background "#000000" \
    -gravity center \
    -extent "${WIDTH}x${HEIGHT}" \
    "$DST" >/dev/null 2>&1
elif command -v sips >/dev/null 2>&1; then
  max_side="$WIDTH"
  if [ "$HEIGHT" -gt "$WIDTH" ]; then
    max_side="$HEIGHT"
  fi
  sips -Z "$max_side" "$SRC" --out "$DST" >/dev/null 2>&1
else
  # sips が無い場合はそのままコピーし、背景サイズでスケールに任せる
  cp "$SRC" "$DST"
fi

exit 0
