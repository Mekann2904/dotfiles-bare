#!/bin/bash
# plugins/setup_keychain.sh
# KeychainにAPIキーを登録するスクリプト

setup_keychain() {
  local service_name="$1"
  local display_name="$2"
  local api_key="$3"

  # 既存のエントリがあれば削除
  if security find-generic-password -s "$service_name" -a "api-key" &>/dev/null; then
    echo "既存のエントリを削除しています: $display_name"
    security delete-generic-password -s "$service_name" -a "api-key" >/dev/null 2>&1
  fi

  # Keychainに追加
  if security add-generic-password \
    -s "$service_name" \
    -a "api-key" \
    -w "$api_key" \
    -U \
    -T "/usr/bin/security" \
    -T "/bin/bash" \
    -T "/bin/zsh" \
    2>/dev/null; then
    echo "✓ $display_name APIキーをKeychainに正常に登録しました"
    return 0
  else
    echo "✗ $display_name Keychainへの登録に失敗しました"
    return 1
  fi
}

# DeepSeek APIキーのセットアップ
echo "DeepSeek APIキーをKeychainに登録します"
echo "https://platform.deepseek.com/api-keys でAPIキーを取得できます"
echo ""

DEEPSEEK_API_KEY=""
while [ -z "$DEEPSEEK_API_KEY" ]; do
  read -s -p "DeepSeek APIキーを入力してください: " DEEPSEEK_API_KEY
  echo ""

  if [ -z "$DEEPSEEK_API_KEY" ]; then
    echo "エラー: APIキーが入力されませんでした"
  elif [[ ! "$DEEPSEEK_API_KEY" =~ ^sk-[a-zA-Z0-9]+$ ]]; then
    echo "警告: APIキーの形式が正しくない可能性があります（例: sk-xxxxxxxx）"
    read -p "このまま続行しますか？ (y/n): " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
      DEEPSEEK_API_KEY=""
    fi
  fi
done

echo ""

# Tasks APIキーのセットアップ
echo "Tasks APIキーをKeychainに登録します"
echo ""

TASKS_API_KEY=""
while [ -z "$TASKS_API_KEY" ]; do
  read -s -p "Tasks APIキーを入力してください（以前の値: r3iMVBxVM-czqeapGrvYF9DdYHDoiD7XTiwteJQ36Oc）: " TASKS_API_KEY
  echo ""

  if [ -z "$TASKS_API_KEY" ]; then
    echo "エラー: APIキーが入力されませんでした"
  fi
done

echo ""

# 両方のAPIキーをKeychainに登録
setup_keychain "sketchybar-deepseek" "DeepSeek" "$DEEPSEEK_API_KEY"
DEEPSEEK_RESULT=$?

setup_keychain "sketchybar-tasks" "Tasks" "$TASKS_API_KEY"
TASKS_RESULT=$?

echo ""
echo "確認コマンド:"
echo "  DeepSeek: security find-generic-password -s 'sketchybar-deepseek' -a 'api-key' -w"
echo "  Tasks:    security find-generic-password -s 'sketchybar-tasks' -a 'api-key' -w"

if [ $DEEPSEEK_RESULT -eq 0 ] && [ $TASKS_RESULT -eq 0 ]; then
  echo ""
  echo "✓ 全てのAPIキーをKeychainに正常に登録しました"
  exit 0
else
  echo ""
  echo "✗ 一部のAPIキーの登録に失敗しました"
  exit 1
fi
