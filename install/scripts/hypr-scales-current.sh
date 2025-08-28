#!/bin/bash
set -euo pipefail

# Resolve monitor name from WAYBAR_OUTPUT; fallback to activewindow's monitor
resolve_monitor_name() {
  local out="${WAYBAR_OUTPUT_NAME:-}"
  local mon_name=""

  if [[ -n "$out" ]]; then
    # Try to match by .name (common case where output name equals Hypr monitor name)
    mon_name="$(hyprctl -j monitors 2>/dev/null | jq -r --arg o "$out" '.[] | select(.name == $o) | .name // empty')"
    if [[ -z "$mon_name" ]]; then
      # Fallback: try matching by .description containing output name
      mon_name="$(hyprctl -j monitors 2>/dev/null | jq -r --arg o "$out" '.[] | select((.description // "") | test($o)) | .name // empty' | head -n1)"
    fi
  fi

  if [[ -z "$mon_name" ]]; then
    # Final fallback: activewindow's monitor id -> name
    local mid
    mid="$(hyprctl -j activewindow 2>/dev/null | jq -r '.monitor // empty')"
    if [[ -n "$mid" ]]; then
      mon_name="$(hyprctl -j monitors 2>/dev/null | jq -r --arg id "$mid" '.[] | select((.id|tostring) == $id) | .name // empty')"
    fi
  fi

  [[ -n "$mon_name" ]] && echo "$mon_name"
}

main() {
  local mon pct
  mon="$(resolve_monitor_name || true)"
  if [[ -z "${mon:-}" ]]; then
    echo "  --%"
    exit 0
  fi

  pct="$(hyprctl -j monitors 2>/dev/null | jq -r --arg m "$mon" '.[] | select(.name == $m) | (.scale * 100)')"
  if [[ -z "${pct:-}" || "$pct" == "null" ]]; then
    echo "  --%"
    exit 0
  fi

  printf "  %s %.0f%%\n" "$mon" "$pct"
}

main "$@"
