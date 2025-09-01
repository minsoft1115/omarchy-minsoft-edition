#!/bin/bash
set -euo pipefail

###
# Hyprland Monitor Scale Selector
# - Shows 4 scale options for the active monitor: 100%, 125%, 150%, 200%
# - Displays the current scale in the prompt (e.g., "( Current : 150% )")
# - Applies the change using `hyprctl keyword monitor ...`
###

LOCKFILE="/tmp/hypr-monitor-scale.lock"
exec 9>"$LOCKFILE" || exit 0
if ! flock -n 9; then
  exit 0
fi
trap 'rm -f "$LOCKFILE" 2>/dev/null || true' EXIT INT TERM

# Get the active monitor name from the active workspace
get_active_monitor_name() {
  local wsname monname
  wsname="$(hyprctl -j activeworkspace 2>/dev/null | jq -r '.name // empty')"
  [[ -z "$wsname" ]] && exit 0

  monname="$(hyprctl -j monitors | jq -r --arg ws "$wsname" \
    '.[] | select(.activeWorkspace.name == $ws) | .name // empty')"
  [[ -z "$monname" ]] && exit 0

  echo "$monname"
}

# Get the current scale for a given monitor
get_current_scale() {
  local monitor="$1"
  hyprctl -j monitors | jq -r --arg mon "$monitor" \
    '.[] | select(.name == $mon) | (.scale * 100 | round | tostring + " %")'
}

# Get the current resolution string for a given monitor
get_current_resolution() {
  local monitor="$1"
  hyprctl -j monitors | jq -r --arg mon "$monitor" \
    '.[] | select(.name == $mon) | "\(.width)x\(.height)@\(.refreshRate)"'
}

# Show menu with scale options
show_scale_menu() {
  local monitor="$1"
  local current_scale="$2"

  local options=("100 %" "125 %" "150 %" "200 %")
  for opt in "${options[@]}"; do
    echo "$opt"
  done | walker --dmenu -p "Scale for $monitor ( Current : $current_scale )" \
    --theme dmenu_250 -w 400
}

# Apply selected scale in Hyprland
apply_scale() {
  local monitor="$1"
  local scale_str="$2"

  # scale 문자열 -> 실수
  local scale_val
  case "$scale_str" in
  "100 %") scale_val="1.0" ;;
  "125 %") scale_val="1.25" ;;
  "150 %") scale_val="1.5" ;;
  "200 %") scale_val="2.0" ;;
  *)
    echo "unknown scale: $scale_str"
    return 0
    ;;
  esac

  # 현재 모니터 JSON
  local j mon
  j="$(hyprctl -j monitors)"
  mon="$(echo "$j" | jq -r ".[] | select(.name==\"$monitor\")")"
  if [[ -z "$mon" || "$mon" == "null" ]]; then
    echo "monitor not found: $monitor" >&2
    return 1
  fi

  # 현재 해상도/주사율
  local width height cur_hz
  width="$(echo "$mon" | jq -r '.width')"
  height="$(echo "$mon" | jq -r '.height')"
  cur_hz="$(echo "$mon" | jq -r '(.refresh_rate // .refreshRate)')"

  # 같은 해상도의 availableModes 중 현재 Hz와 최솟차 모드 선택
  local candidates best_line best_mode
  candidates="$(echo "$mon" | jq -r --arg W "$width" --arg H "$height" '.availableModes[] | select(startswith($W + "x" + $H + "@"))')"

  if [[ -n "$candidates" ]]; then
    best_line="$(
      awk -v cur="$cur_hz" '
        function abs(x){return x<0?-x:x}
        {
          mode=$0
          hz=mode
          sub(/^.*@/, "", hz)   # 59.94Hz
          sub(/Hz$/, "", hz)    # 59.94
          diff=abs(cur - hz)
          printf("%.9f %s\n", diff, mode)
        }
      ' <<<"$candidates" | LC_ALL=C sort -g | head -n1
    )"
    best_mode="${best_line#* }"
  fi

  # fallback: 후보가 없으면 60.00Hz 시도
  if [[ -z "$best_mode" ]]; then
    best_mode="${width}x${height}@60.00Hz"
  fi

  # 적용: pos는 auto로, 나머지는 명시
  hyprctl keyword monitor "${monitor},${best_mode},auto,${scale_val}" >/dev/null 2>&1
}

# Main flow
main() {
  local mon choice current_scale current_res
  mon="$(get_active_monitor_name)" || exit 0
  current_scale="$(get_current_scale "$mon")"
  current_res="$(get_current_resolution "$mon")"

  choice="$(show_scale_menu "$mon" "$current_scale" 2>/dev/null || true)"
  [[ -z "${choice:-}" ]] && exit 0

  apply_scale "$mon" "$choice" "$current_res"
}

main "$@"
