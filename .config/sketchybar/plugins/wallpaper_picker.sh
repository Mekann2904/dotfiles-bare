#!/usr/bin/env bash
# plugins/wallpaper_picker.sh
# SwiftDialog を使い、画面全体でタイル表示する壁紙ピッカーを起動するランチャー。
# バーのポップアップ制約を避けて広いプレビューで即時切替するために存在する。
# 関連ファイル: sketchybarrc, plugins/wallpaper.sh, plugins/wallpaper_preview.sh, plugins/wallpaper_list.sh

set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
PLUGIN_DIR="$CONFIG_DIR/plugins"
WALLPAPER_DIR="${WALLPAPER_DIR:-$CONFIG_DIR/wallpapers}"
COMMAND_FILE="${COMMAND_FILE:-/tmp/swiftdialog_wallpaper.cmd}"
SWIFTDIALOG_BIN="/usr/local/bin/dialog"

# SwiftDialog が無ければ終了
if [ ! -x "$SWIFTDIALOG_BIN" ]; then
  echo "swiftDialog が見つかりません: $SWIFTDIALOG_BIN" >&2
  exit 1
fi

# 壁紙がなければフォルダを案内して終了
shopt -s nullglob
wallpapers=("$WALLPAPER_DIR"/*.{png,jpg,jpeg,webp,heic,heif})
shopt -u nullglob
if [ ${#wallpapers[@]} -eq 0 ]; then
  osascript -e "display notification \"壁紙フォルダに画像がありません\" with title \"SketchyBar\""
  exit 0
fi

tmp_dir="$(mktemp -d /tmp/wallpaper_picker.XXXXXX)"
html_path="$tmp_dir/index.html"
server_script="$tmp_dir/server.py"

# コマンドファイル初期化
: > "$COMMAND_FILE"

# HTML を生成（CSS Grid で自動タイル）
cat >"$html_path" <<'HTML'
<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>壁紙を選択</title>
  <style>
    :root {
      color-scheme: dark;
      --bg: #0b0c10;
      --card: #12141c;
      --accent: #4fd1c5;
      --text: #e4e8f0;
      --muted: #8b92a7;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      padding: 24px;
      background: radial-gradient(circle at 20% 20%, #1b1f2f 0, #0b0c10 40%),
                  radial-gradient(circle at 80% 0%, #11202b 0, #0b0c10 42%),
                  #0b0c10;
      font-family: "SF Pro Display", "Inter", system-ui, -apple-system, sans-serif;
      color: var(--text);
    }
    header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      padding: 4px 0 20px;
      position: sticky;
      top: 0;
      background: linear-gradient(180deg, rgba(11,12,16,0.95) 0%, rgba(11,12,16,0.65) 60%, rgba(11,12,16,0) 100%);
      backdrop-filter: blur(8px);
      z-index: 2;
    }
    h1 { margin: 0; font-size: 20px; letter-spacing: 0.02em; }
    .hint { color: var(--muted); font-size: 13px; }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
      gap: 16px;
    }
    .card {
      position: relative;
      background: var(--card);
      border: 1px solid rgba(255,255,255,0.06);
      border-radius: 14px;
      overflow: hidden;
      box-shadow: 0 20px 50px rgba(0,0,0,0.35);
      transition: transform 0.2s ease, border-color 0.2s ease, box-shadow 0.2s ease;
      cursor: pointer;
      isolation: isolate;
    }
    .card:hover {
      transform: translateY(-4px);
      border-color: rgba(79,209,197,0.7);
      box-shadow: 0 30px 60px rgba(0,0,0,0.45);
    }
    .card img {
      width: 100%;
      height: 220px;
      object-fit: cover;
      display: block;
    }
    .meta {
      padding: 10px 12px 12px;
      font-size: 13px;
      color: var(--muted);
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .dot {
      width: 10px;
      height: 10px;
      border-radius: 50%;
      background: var(--accent);
      box-shadow: 0 0 0 6px rgba(79,209,197,0.15);
      flex-shrink: 0;
    }
    .toast {
      position: fixed;
      bottom: 18px;
      right: 18px;
      padding: 12px 16px;
      background: rgba(17, 24, 39, 0.92);
      border: 1px solid rgba(79,209,197,0.6);
      border-radius: 12px;
      color: var(--text);
      font-size: 13px;
      opacity: 0;
      transform: translateY(8px);
      transition: opacity 0.18s ease, transform 0.18s ease;
      box-shadow: 0 20px 40px rgba(0,0,0,0.45);
      z-index: 5;
    }
    .toast.show {
      opacity: 1;
      transform: translateY(0);
    }
  </style>
</head>
<body>
  <header>
    <div>
      <h1>壁紙を選択</h1>
      <div class="hint">クリックで即適用。Esc で閉じる。</div>
    </div>
  </header>
  <main class="grid" id="grid"></main>
  <div class="toast" id="toast">壁紙を適用しました</div>
  <script>
    const items = [];
    const grid = document.getElementById('grid');
    const toast = document.getElementById('toast');
    function showToast() {
      toast.classList.add('show');
      setTimeout(() => toast.classList.remove('show'), 1400);
    }
    async function apply(file) {
      try {
        await fetch('/select?file=' + encodeURIComponent(file));
        showToast();
      } catch (e) {
        alert('設定に失敗しました: ' + e);
      }
    }
    function addCard(file, label, preview) {
      const card = document.createElement('div');
      card.className = 'card';
      card.innerHTML = `
        <img src="${preview}" alt="${label}" loading="lazy" />
        <div class="meta"><span class="dot"></span><span>${label}</span></div>
      `;
      card.onclick = () => apply(file);
      grid.appendChild(card);
    }
    window.addEventListener('DOMContentLoaded', () => {
      fetch('/list.json').then(r => r.json()).then(data => {
        data.items.forEach(it => addCard(it.file, it.label, it.preview));
      }).catch(err => {
        alert('リスト取得に失敗しました: ' + err);
      });
    });
  </script>
</body>
</html>
HTML

# Python サーバー: HTML/JSON/画像を配信し、選択時に壁紙変更 + Dialog終了を指示
cat >"$server_script" <<'PY'
import http.server, socketserver, urllib.parse, json, os, subprocess, sys, mimetypes

wallpaper_dir = sys.argv[1]
command_file = sys.argv[2]
plugin_dir = sys.argv[3]
html_path = sys.argv[4]
preview_root = sys.argv[5]
port = int(sys.argv[6])

wallpaper_dir = os.path.abspath(wallpaper_dir)
preview_root = os.path.abspath(preview_root)

def build_list():
    items = []
    exts = ('.png','.jpg','.jpeg','.webp','.heic','.heif')
    for entry in sorted(os.listdir(wallpaper_dir)):
        if not entry.lower().endswith(exts):
            continue
        src = os.path.join(wallpaper_dir, entry)
        if not os.path.isfile(src):
            continue
        preview = f\"/img/{entry}\"
        items.append({\"file\": entry, \"label\": entry, \"preview\": preview})
    return items

class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args, **kwargs):
        pass

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        if path == '/':
            return self._serve_file(html_path, 'text/html; charset=utf-8')
        if path == '/list.json':
            data = {\"items\": build_list()}
            raw = json.dumps(data).encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)
            return
        if path.startswith('/img/'):
            rel = path[len('/img/'):]
            rel = os.path.basename(rel)
            target = os.path.join(wallpaper_dir, rel)
            if not target.startswith(wallpaper_dir) or not os.path.isfile(target):
                self.send_error(404)
                return
            mime, _ = mimetypes.guess_type(target)
            return self._serve_file(target, mime or 'application/octet-stream')
        if path == '/select':
            query = urllib.parse.parse_qs(parsed.query)
            rel = query.get('file', [''])[0]
            rel = os.path.basename(rel)
            target = os.path.join(wallpaper_dir, rel)
            if not target.startswith(wallpaper_dir) or not os.path.isfile(target):
                self.send_error(400, 'invalid file')
                return
            subprocess.Popen([os.path.join(plugin_dir, 'wallpaper.sh'), target, 'avatar'])
            with open(command_file, 'a', encoding='utf-8') as cf:
                cf.write('quit:\\n')
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'ok')
            return
        self.send_error(404)

    def _serve_file(self, path, mime):
        try:
            with open(path, 'rb') as f:
                data = f.read()
            self.send_response(200)
            self.send_header('Content-Type', mime)
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        except FileNotFoundError:
            self.send_error(404)

with socketserver.TCPServer(('127.0.0.1', port), Handler) as httpd:
    httpd.serve_forever()
PY

# 空きポートを取得
PORT="$(python3 - <<'PY'
import socket
s=socket.socket()
s.bind(('127.0.0.1',0))
print(s.getsockname()[1])
s.close()
PY
)"

# サーバー起動
python3 "$server_script" "$WALLPAPER_DIR" "$COMMAND_FILE" "$PLUGIN_DIR" "$html_path" "$tmp_dir" "$PORT" &
server_pid=$!

cleanup() {
  kill "$server_pid" >/dev/null 2>&1 || true
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

# SwiftDialog をフルスクリーンで起動
"$SWIFTDIALOG_BIN" \
  --title "壁紙ギャラリー" \
  --message "クリックで適用 / Esc で閉じる" \
  --webcontent "http://127.0.0.1:$PORT/" \
  --commandfile "$COMMAND_FILE" \
  --fullscreen \
  --blurscreen \
  --button1text "閉じる" \
  --button1disabled \
  --quitkey esc \
  || true

exit 0
