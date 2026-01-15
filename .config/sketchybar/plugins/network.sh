#!/bin/bash
# plugins/network.sh
# ネットワーク種別とRSSIを表示し、差分計測でアップ/ダウン速度を推定する。
# 回線状態を簡潔に把握するために存在する（オフライン時は非表示）。
# 関連ファイル: sketchybarrc, plugins/battery.sh, plugins/volume.sh, plugins/clock.sh

# Network status plugin for sketchybar
# Shows WiFi or Ethernet icon with upload/download speeds when connected, nothing when offline

NETWORK_CACHE_DIR="$HOME/.config/sketchybar/.cache"
NETWORK_CACHE_FILE="$NETWORK_CACHE_DIR/network_stats"

# Create cache directory if it doesn't exist
mkdir -p "$NETWORK_CACHE_DIR"

get_active_interface() {
    # Get the default route interface
    local interface=$(route get default 2>/dev/null | grep "interface:" | awk '{print $2}')
    echo "$interface"
}

get_network_speeds() {
    local interface=$(get_active_interface)
    
    if [[ -z "$interface" ]]; then
        echo "0 0"
        return
    fi
    
    # Get current network statistics using netstat
    local current_stats=$(netstat -I "$interface" -b 2>/dev/null | grep "$interface" | head -1)
    if [[ -z "$current_stats" ]]; then
        echo "0 0"
        return
    fi
    
    local current_time=$(date +%s)
    local current_bytes_in=$(echo "$current_stats" | awk '{print $7}')
    local current_bytes_out=$(echo "$current_stats" | awk '{print $10}')
    
    # Read previous stats from cache
    local previous_time=0
    local previous_bytes_in=0
    local previous_bytes_out=0
    
    if [[ -f "$NETWORK_CACHE_FILE" ]]; then
        read previous_time previous_bytes_in previous_bytes_out < "$NETWORK_CACHE_FILE"
    fi
    
    # Calculate speeds (bytes per second)
    local time_diff=$((current_time - previous_time))
    
    local download_speed=0
    local upload_speed=0
    
    if [[ $time_diff -gt 0 ]]; then
        download_speed=$(( (current_bytes_in - previous_bytes_in) / time_diff ))
        upload_speed=$(( (current_bytes_out - previous_bytes_out) / time_diff ))
    fi
    
    # Save current stats to cache
    local tmp_cache="${NETWORK_CACHE_FILE}.$$"
    echo "$current_time $current_bytes_in $current_bytes_out" > "$tmp_cache"
    mv "$tmp_cache" "$NETWORK_CACHE_FILE"
    
    echo "$download_speed $upload_speed"
}

format_speed() {
    local speed=$1
    
    if [[ $speed -gt 1048576 ]]; then
        # Format as MB - ensure exactly 3 characters using significant figures
        local mb=$(echo "scale=1; $speed / 1048576" | bc -l)
        if (( $(echo "$mb < 10" | bc -l) )); then
            # Values under 10: show 1 decimal place (e.g., 1.2M, 9.9M)
            printf "%.1fM" $mb
        else
            # Values 10-99: show integer (e.g., 12M, 99M)
            printf "%.0fM" $mb
        fi
    elif [[ $speed -gt 1024 ]]; then
        # Format as KB - ensure exactly 3 characters using significant figures
        local kb=$(echo "scale=1; $speed / 1024" | bc -l)
        if (( $(echo "$kb < 10" | bc -l) )); then
            # Values under 10: show 1 decimal place (e.g., 1.2K, 9.9K)
            printf "%.1fK" $kb
        else
            # Values 10-99: show integer (e.g., 12K, 99K)
            printf "%.0fK" $kb
        fi
    else
        # Format bytes - ensure exactly 3 characters
        printf "%3dB" $speed
    fi
}

get_rssi_strength() {
    local interface=$1
    local rssi=""
    
    if [[ "$interface" == "en0" ]]; then
        # Get current WiFi signal strength using system_profiler
        rssi=$(system_profiler SPAirPortDataType 2>/dev/null | grep "Signal / Noise" | head -1 | awk -F':' '{print $2}' | awk '{print $1}' | tr -d ' ')
    fi
    
    echo "$rssi"
}

get_network_status() {
    local interface=$(get_active_interface)
    
    if [[ -n "$interface" ]]; then
        # Determine connection type
        local icon=""
        if [[ "$interface" == "en0" ]]; then
            icon="󰖩"  # WiFi
        else
            icon="󰈀"  # Ethernet
        fi
        
        # Get RSSI signal strength
        local rssi=$(get_rssi_strength "$interface")
        
        # Show connection icon and RSSI value with unit
        if [[ -n "$rssi" && "$rssi" =~ ^-?[0-9]+$ ]]; then
            echo "$icon ${rssi}dBm"
        else
            echo "$icon"
        fi
    else
        echo ""
    fi
}

update_network_display() {
    local status=$(get_network_status)
    
    if [[ -n "$status" ]]; then
        sketchybar --set network \
            label="$status" \
            drawing=on
    else
        sketchybar --set network \
            drawing=off
    fi
}

case "$SENDER" in
    "network_change"|"routine"|"forced")
        update_network_display
        ;;
    *)
        update_network_display
        ;;
esac
