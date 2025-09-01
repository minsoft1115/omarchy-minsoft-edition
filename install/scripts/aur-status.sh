#!/usr/bin/env bash

AUR_URL="https://aur.archlinux.org/rpc/v5/info?arg[]=pacman"
TIMEOUT=3

# Record start timestamp in milliseconds
start_ts=$(
  date +%s%3N 2>/dev/null || python - <<'PY'
import time; print(int(time.time()*1000))
PY
)

# Perform HTTP request to AUR API
http_resp=$(curl -sS -m "$TIMEOUT" -w " HTTPSTATUS:%{http_code}" "$AUR_URL" 2>&1)
curl_ec=$?

# Record end timestamp in milliseconds
end_ts=$(
  date +%s%3N 2>/dev/null || python - <<'PY'
import time; print(int(time.time()*1000))
PY
)

# Calculate latency
latency_ms=$((end_ts - start_ts))

# 마지막 체크 시각(로컬 타임존) 생성 - 추가
last_check=$(date +"%Y-%m-%d %H:%M:%S %Z")

# Default status values
status="down"
icon="󰁪"
tooltip="AUR unreachable"
klass="red"

if [ $curl_ec -eq 0 ]; then
  body="${http_resp% HTTPSTATUS:*}"
  code="${http_resp##*HTTPSTATUS:}"

  if [ "$code" = "200" ]; then
    # Simple validation: check JSON field "type"
    typ=$(printf '%s' "$body" | jq -r '.type' 2>/dev/null)
    if [ "$typ" = "multiinfo" ] || [ "$typ" = "search" ]; then
      status="up"
      icon="󰖩"
      tooltip="AUR OK • ${latency_ms}ms"
      klass="green"
      # If latency is higher than threshold, set warning class
      if [ "$latency_ms" -gt 1000 ]; then
        klass="yellow"
        tooltip="AUR slow • ${latency_ms}ms"
      fi
    else
      tooltip="AUR bad response • type=${typ:-null}"
      klass="yellow"
      icon=""
    fi
  else
    tooltip="AUR HTTP ${code}"
    icon=""
    klass="red"
  fi
else
  tooltip="curl error ${curl_ec}"
  icon=""
  klass="red"
fi

# tooltip에 마지막 체크 시각 추가 - 추가
tooltip="Result : ${tooltip}\nChecked : ${last_check}"

# Output JSON for Waybar custom module
# text: icon or short status, tooltip: detailed message, class: for color via CSS
printf '{"text":"%s","tooltip":"%s","class":"%s","alt":"%s"}\n' \
  "$icon AUR" "$tooltip" "$klass" "$status"
