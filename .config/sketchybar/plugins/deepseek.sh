#!/bin/bash
# plugins/deepseek.sh
# DeepSeek APIのクレジット残高を取得して表示する。
# 関連ファイル: sketchybarrc, plugins/battery.sh

# 画像パスの初期化（必ず最初に定義）
ICON_PATH="$(dirname "$0")/deepseek.png"

# デバッグログ設定（必要時のみ）
DEBUG_LOG_FILE="${DEBUG_LOG:-}"
if [ -z "$DEBUG_LOG_FILE" ] && [ "${SKETCHYBAR_DEEPSEEK_DEBUG:-}" = "1" ]; then
  DEBUG_LOG_FILE="/tmp/sketchybar_deepseek_debug.log"
fi
log_debug() {
  [ -n "$DEBUG_LOG_FILE" ] || return 0
  echo "$(date '+%Y-%m-%d %H:%M:%S') [DEEPSEEK] $*" >> "$DEBUG_LOG_FILE"
}

# キャッシュ設定
CACHE_FILE="${DEEPSEEK_CACHE_FILE:-/tmp/sketchybar_deepseek_cache}"
CACHE_TTL="${DEEPSEEK_CACHE_TTL:-21600}"

write_cache() {
  local value="$1"
  printf '%s\t%s' "$(date +%s)" "$value" > "$CACHE_FILE" 2>/dev/null || true
}

read_cache() {
  [ -f "$CACHE_FILE" ] || return 1
  local ts value now age
  IFS=$'\t' read -r ts value < "$CACHE_FILE" || return 1
  [ -n "$value" ] || return 1
  now=$(date +%s)
  age=$((now - ts))
  if [ "$age" -le "$CACHE_TTL" ]; then
    printf '%s' "$value"
    return 0
  fi
  printf '%s' "$value"
  return 2
}

# KeychainからAPIキーを取得する関数
get_deepseek_api_key() {
  local service="sketchybar-deepseek"
  local account="api-key"
  local api_key

  if command -v security >/dev/null 2>&1; then
    api_key=$(security find-generic-password -s "$service" -a "$account" -w 2>/dev/null)
    if [ -n "$api_key" ]; then
      echo "$api_key"
      return 0
    else
      log_debug "API key not found in Keychain (service: $service, account: $account)"
      return 1
    fi
  else
    log_debug "security command not available"
    return 1
  fi
}

# APIキーの確認（Keychainから取得）
DEEPSEEK_API_KEY=$(get_deepseek_api_key)

if [ -z "$DEEPSEEK_API_KEY" ]; then
  log_debug "DEEPSEEK_API_KEY not found in Keychain"
  sketchybar --set "$NAME" \
    icon="" \
    icon.background.image="$ICON_PATH" \
    icon.background.drawing=on \
    icon.background.image.scale=0.01 \
    label="N/A" \
    drawing=on
  exit 0
fi

# 残高を取得する関数
get_deepseek_balance() {
  local api_key="$1"
  local response
  local exit_code

  response=$(curl -sS \
    --connect-timeout 3 \
    --max-time 8 \
    --retry 2 \
    --retry-delay 1 \
    --retry-connrefused \
    -H "Authorization: Bearer $api_key" \
    "https://api.deepseek.com/user/balance" 2>&1)
  exit_code=$?

  if [ $exit_code -ne 0 ]; then
    log_debug "curl failed with exit code $exit_code: $response"
    return 1
  fi

  if [ -z "$response" ]; then
    log_debug "Empty response from API"
    return 1
  fi

  log_debug "API response: $response"

  # JSONをパースして残高を取得
  if command -v jq >/dev/null 2>&1; then
    local is_available
    local balance_infos
    local total_balance

    is_available=$(echo "$response" | jq -r '.is_available // false')
    balance_infos=$(echo "$response" | jq -r '.balance_infos // empty')

    if [ "$is_available" = "false" ]; then
      log_debug "API indicates balance not available"
      BALANCE="0"
    elif [ -n "$balance_infos" ]; then
      total_balance=$(echo "$response" | jq -r '.balance_infos[0].total_balance // "0"')
      if [ "$total_balance" = "null" ] || [ -z "$total_balance" ]; then
        log_debug "balance_infos array is empty or invalid"
        return 1
      fi
      BALANCE="$total_balance"
    else
      log_debug "Failed to parse balance from response"
      return 1
    fi
  else
    local balance_match
    balance_match=$(echo "$response" | grep -o '"total_balance":"[^"]*"' | head -1 | cut -d'"' -f4)
    if [ -n "$balance_match" ]; then
      BALANCE="$balance_match"
    else
      log_debug "Failed to parse balance from response (jq not available)"
      return 1
    fi
  fi

  if [[ ! "$BALANCE" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    log_debug "Invalid balance format: $BALANCE"
    return 1
  fi

  log_debug "Balance retrieved: $BALANCE"
  write_cache "$BALANCE"
  return 0
}

# メイン処理
if ! get_deepseek_balance "$DEEPSEEK_API_KEY"; then
  cached_balance="$(read_cache)"
  if [ -n "$cached_balance" ]; then
    log_debug "Using cached balance due to API error"
    FORMATTED_BALANCE=$(printf "%.2f" "$cached_balance" 2>/dev/null || echo "$cached_balance")
    sketchybar --set "$NAME" \
      icon="" \
      icon.background.image="$ICON_PATH" \
      icon.background.drawing=on \
      icon.background.image.scale=0.01 \
      label="$FORMATTED_BALANCE" \
      drawing=on
    exit 0
  fi

  sketchybar --set "$NAME" \
    icon="" \
    icon.background.image="$ICON_PATH" \
    icon.background.drawing=on \
    icon.background.image.scale=0.01 \
    label="--" \
    drawing=on
  log_debug "Displaying error state due to API error"
  exit 0
fi

# 残高を小数点以下2桁にフォーマット
FORMATTED_BALANCE=$(printf "%.2f" "$BALANCE" 2>/dev/null || echo "$BALANCE")

# SketchyBarのアイテムを更新
sketchybar --set "$NAME" \
  icon="" \
  icon.background.image="$ICON_PATH" \
  icon.background.drawing=on \
  icon.background.image.scale=0.01 \
  label="$FORMATTED_BALANCE" \
  drawing=on
log_debug "DeepSeek balance updated: $FORMATTED_BALANCE"
