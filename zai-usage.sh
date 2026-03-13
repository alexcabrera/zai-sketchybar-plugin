#!/bin/bash

# Read ZAI_API_KEY from environment files (SketchyBar runs without shell env)
get_env_var() {
  local var="$1"
  for file in "$HOME/.zshenv" "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
    if [[ -f "$file" ]]; then
      local val=$(grep -E "^export ${var}=" "$file" 2>/dev/null | head -1 | sed "s/^export ${var}=\"\\{0,1\\}//;s/\"\\{0,1\}$//")
      if [[ -n "$val" ]]; then
        echo "$val"
        return
      fi
    fi
  done
}

CACHE_FILE="/tmp/sketchybar-zai-cache.json"
CACHE_TTL=300

get_platform() {
  local platform=$(get_env_var "ZAI_PLATFORM")
  echo "${platform:-global}"
}

get_base_url() {
  local platform="$1"
  if [[ "$platform" == "china" ]]; then
    echo "https://open.bigmodel.cn"
  else
    echo "https://api.z.ai"
  fi
}

get_time_windows() {
  python3 << 'EOF'
from datetime import datetime, timedelta
import calendar

now = datetime.now()
current_hour = now.replace(minute=0, second=0, microsecond=0)
end = current_hour + timedelta(hours=1)
end_with_seconds = end.replace(second=59)

# 24-hour window
daily_start = end - timedelta(days=1)

# Weekly window
weekly_start = end - timedelta(days=7)

def format_dt(dt):
    return dt.strftime("%Y-%m-%d %H:%M:%S")

print(format_dt(daily_start))
print(format_dt(end_with_seconds))
print(format_dt(weekly_start))
EOF
}

read_windows=$(get_time_windows)
DAILY_START=$(echo "$read_windows" | sed -n '1p')
DAILY_END=$(echo "$read_windows" | sed -n '2p')
WEEKLY_START=$(echo "$read_windows" | sed -n '3p')

fetch_data() {
  local api_key="$1"
  local base_url="$2"

  # URL encode the time parameters
  local encoded_start=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$WEEKLY_START'))")
  local encoded_end=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$DAILY_END'))")

  local quota_url="${base_url}/api/monitor/usage/quota/limit"
  local weekly_url="${base_url}/api/monitor/usage/model-usage?startTime=${encoded_start}&endTime=${encoded_end}"

  local quota_response weekly_response

  quota_response=$(curl -s -m 10 -H "Authorization: $api_key" -H "Content-Type: application/json" "$quota_url" 2>/dev/null)
  weekly_response=$(curl -s -m 10 -H "Authorization: $api_key" -H "Content-Type: application/json" "$weekly_url" 2>/dev/null)

  echo "$quota_response|$weekly_response"
}

format_tokens() {
  local tokens="$1"
  if [[ $tokens -ge 1000000 ]]; then
    echo "$((tokens / 1000000))M"
  elif [[ $tokens -ge 1000 ]]; then
    echo "$((tokens / 1000))K"
  else
    echo "$tokens"
  fi
}

get_status_color() {
  local percentage="$1"
  percentage=${percentage%.*}
  if [[ $percentage -ge 90 ]]; then
    echo "0xFFFF0000"
  elif [[ $percentage -ge 70 ]]; then
    echo "0xFFFF9500"
  elif [[ $percentage -ge 50 ]]; then
    echo "0xFFFFFF00"
  else
    echo "0xFF00FF00"
  fi
}

API_KEY=$(get_env_var "ZAI_API_KEY")

if [[ -z "$API_KEY" ]]; then
  sketchybar --set "$NAME" icon="󰠞" label="setup" icon.color=0xFFFF9500
  exit 0
fi

PLATFORM=$(get_platform)
BASE_URL=$(get_base_url "$PLATFORM")

CACHE_VALID=false
if [[ -f "$CACHE_FILE" ]]; then
  cache_age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0) ))
  if [[ $cache_age -lt $CACHE_TTL ]]; then
    CACHE_VALID=true
  fi
fi

if [[ "$CACHE_VALID" == true ]]; then
  data=$(cat "$CACHE_FILE")
else
  data=$(fetch_data "$API_KEY" "$BASE_URL")
  if [[ -n "$data" ]]; then
    echo "$data" > "$CACHE_FILE"
  fi
fi

quota_json=$(echo "$data" | cut -d'|' -f1)
weekly_json=$(echo "$data" | cut -d'|' -f2)

token_percentage=$(echo "$quota_json" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for limit in data.get('data', {}).get('limits', []):
        if limit.get('type') == 'TOKENS_LIMIT' and limit.get('unit') == 3:
            print(int(limit.get('percentage', 0)))
            break
    else:
        print(0)
except:
    print(0)
" 2>/dev/null)

weekly_percentage=$(echo "$quota_json" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for limit in data.get('data', {}).get('limits', []):
        if limit.get('type') == 'TOKENS_LIMIT' and limit.get('unit') == 6:
            print(int(limit.get('percentage', 0)))
            break
    else:
        print(0)
except:
    print(0)
" 2>/dev/null)
color=$(get_status_color "${weekly_percentage:-0}")

sketchybar --set "$NAME" \
  icon="󰠞" \
  label="${token_percentage}% · ${weekly_percentage}%/wk" \
  icon.color="$color" \
  label.color="$color"
