<!-- docs/status.md -->
<!-- SketchyBar設定とプラグインの現状をまとめたメモ -->
<!-- 新規参加者が全体像を素早く把握するための概要ドキュメント -->
<!-- 関連ファイル: sketchybarrc, plugins/update_single_workspace.sh, plugins/update_workspace_icons.sh, plugins/workspace_events.sh -->

# 概要
トップバーをSketchyBarで構成し、AeroSpaceのワークスペースイベントに反応して左側のタイルを更新する。  
右側は時計・音量・バッテリー・ネットワーク・RAMを表示する。  
全スクリプトは`CONFIG_DIR`配下（デフォルトは`~/.config/sketchybar`）で動作する。  

# ワークスペース更新フロー
- `sketchybarrc`が不可視アイテム`workspace.refresh`に`plugins/workspace_events.sh`を紐づけ、workspace系イベントをまとめて受ける。  
- `workspace_events.sh`はイベントを `focus-only` / `targeted` / `full` に分ける。  
  - `workspace_manual_change` / `aerospace_workspace_change` は `targeted` 扱い。  
  - `window_focused` / `front_app_switched` は `focus-only` 扱い。  
  - `workspace_content_change` / 起動・破棄系イベント / poll は `full` 扱い。  
  - `targeted` では focused workspace だけのウィンドウ一覧と hidden 用の最小問い合わせを行い、アイコン列の遅れを抑える。  
  - `full` では全体スナップショットを取り、起動・破棄系イベントだけ delayed rerun で補完する。  
- `update_single_workspace.sh`は renderer として動き、同じスナップショットから次を1回の`sketchybar`コマンドで反映する。  
  - workspace番号のフォーカス色  
  - underline 表示  
  - 各 workspace の app icon スロット  
  - `more` 表示  
  - 右側 `hidden.icon*` 表示  
- `plugins/workspace_select.sh` は click 用ラッパー。AeroSpace 切り替え成功後に `workspace_manual_change` を送る。  
- 旧来の一括版`plugins/update_workspace_icons.sh`も残存し、ロックを用いて全WSをバッチ更新する実装。フォールバックや比較用に保持。  
- `sketchybarrc`で `MIN_WORKSPACE=1` / `MAX_WORKSPACE=9` を環境変数にエクスポートし、スクリプトとバー定義を同期。  

# 主要プラグインの役割
- `plugins/aerospace.sh`：旧来の個別WSフォーカス更新スクリプト。現行フローでは未使用。  
- `plugins/aerospace_focus.sh`：旧来のフォーカス専用バッチ更新スクリプト。現行フローでは未使用。  
- `plugins/icon_map_fn.sh`：アプリ名→絵文字エイリアスの連想配列。`space_windows.sh`などで再利用可能。  
- `plugins/workspace_select.sh`：workspace クリック後に軽い focus-only event を送るヘルパー。  
- `plugins/space_windows.sh`：可視ワークスペースだけを走査し、アプリ名を絵文字ストリップで表示する簡易版。  
- `plugins/hidden_windows.sh`：hiddenウィンドウの復帰用ヘルパー。表示更新自体は`update_single_workspace.sh`側に集約。  
- `plugins/volume.sh`・`battery.sh`・`network.sh`・`ram_min.sh`・`clock.sh`：右側インジケータ。DEBUG_LOGで任意ログに切替可能。`network.sh`はキャッシュ（`~/.config/sketchybar/.cache/network_stats`）を使って差分計測。`clock.sh`は日付部分を`/tmp/sketchybar_clock_cache`へキャッシュ。  
- `plugins/space_windows.sh`：可視WSのみを絵文字ストリップ表示。  
- `plugins/space.sh`：スペース項目の背景描画ON/OFFのみ担当。  
- `plugins/load_spaces.sh`：未使用の予備追加スクリプト（ヘッダー追記済み）。  
- `plugins/icon_map_fn.sh`：アプリ名→アイコン連想配列ルックアップ。  

# 現状の補足
- `test_performance.sh`で旧新スクリプトの平均実行時間を比較できる。DEBUG_LOGとPERF_LOGを一時ファイルに出力。  
- 一部プラグイン（例: `plugins/network.sh`, `plugins/load_spaces.sh`, `plugins/space.sh` など）はヘッダーコメント未整備。整合性を保つなら追記検討。  
- バックアップとして`sketchybarrc.bak`があり、右側の更新頻度やアイコン設定が現行と微妙に異なる。比較時に参照する。  
