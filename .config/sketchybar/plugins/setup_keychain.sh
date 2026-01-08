#!/bin/bash
# plugins/setup_keychain.sh
# KeychainにDeepSeek APIキーを登録するスクリプト

SERVICE_NAME="sketchybar-deepseek"
ACCOUNT_NAME="api-key"

echo "DeepSeek APIキーをKeychainに登録します"
echo "https://platform.deepseek.com/api-keys でAPIキーを取得できます"
echo ""

while [ -z "$API_KEY" ]; do
  read -s -p "APIキーを入力してください: " API_KEY
  echo ""
  
  if [ -z "$API_KEY" ]; then
    echo "エラー: APIキーが入力されませんでした"
  elif [[ ! "$API_KEY" =~ ^sk-[a-zA-Z0-9]+$ ]]; then
    echo "警告: APIキーの形式が正しくない可能性があります（例: sk-xxxxxxxx）"
    read -p "このまま続行しますか？ (y/n): " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
      API_KEY=""
    fi
  fi
done

echo ""

# 既存のエントリがあれば削除
if security find-generic-password -s "$SERVICE_NAME" -a "$ACCOUNT_NAME" &>/dev/null; then
  echo "既存のエントリを削除しています..."
  security delete-generic-password -s "$SERVICE_NAME" -a "$ACCOUNT_NAME" >/dev/null 2>&1
fi

# Keychainに追加
echo "Keychainに登録しています..."
if security add-generic-password \
  -s "$SERVICE_NAME" \
  -a "$ACCOUNT_NAME" \
  -w "$API_KEY" \
  -U \
  -T "/usr/bin/security" \
  -T "/bin/bash" \
  -T "/bin/zsh" \
  2>/dev/null; then
  echo "✓ APIキーをKeychainに正常に登録しました"
  echo ""
  echo "確認: security find-generic-password -s '$SERVICE_NAME' -a '$ACCOUNT_NAME' -w"
else
  echo "✗ Keychainへの登録に失敗しました"
  exit 1
fi
