#!/usr/bin/env bash
set -euo pipefail

# Colors
RED='\e[31m'
GREEN='\e[32m'
CYAN='\e[36m'
BOLD='\e[1m'
RESET='\e[0m'

MAX_LOG_LINES=5

print_section() {
  local scope="$1" # "System" or "User"
  local units="$2"
  [ -z "$units" ] && return 0

  echo -e "\n${BOLD}${CYAN}[$scope Failed Units]${RESET}"
  for unit in $units; do
    if [ "$scope" = "User" ]; then
      SYSTEMCTL="systemctl --user"
      JOURNALCTL="journalctl --user"
    else
      SYSTEMCTL="systemctl"
      JOURNALCTL="journalctl"
    fi

    local type="${unit##*.}"
    local active sub
    active="$($SYSTEMCTL show "$unit" -p ActiveState --value 2>/dev/null || echo "?")"
    sub="$($SYSTEMCTL show "$unit" -p SubState --value 2>/dev/null || echo "?")"

    # Service header
    echo -e " ${BOLD}${RED}${unit}${RESET} - type: $type  (active: $active, sub: $sub)"

    # Logs (priority err first, fallback to last logs)
    local logs
    logs="$($JOURNALCTL -u "$unit" -b -p err --no-pager 2>/dev/null | tail -n $MAX_LOG_LINES)"
    if [ -z "$logs" ]; then
      logs="$($JOURNALCTL -u "$unit" -b --no-pager 2>/dev/null | tail -n $MAX_LOG_LINES)"
    fi
    if [ -n "$logs" ]; then
      echo "$logs" | sed "s/^/    /"
    else
      echo "    (no recent logs)"
    fi
  done
}

SYS_UNITS=$(systemctl --failed --no-legend --plain | awk '{print $1}')
USR_UNITS=$(systemctl --user --failed --no-legend --plain | awk '{print $1}')

TOTAL=0
[ -n "$SYS_UNITS" ] && TOTAL=$((TOTAL + $(wc -w <<<"$SYS_UNITS")))
[ -n "$USR_UNITS" ] && TOTAL=$((TOTAL + $(wc -w <<<"$USR_UNITS")))

if [ "$TOTAL" -eq 0 ]; then
  echo -e "${GREEN}No failed units.${RESET}"
  exit 0
fi

print_section "System" "$SYS_UNITS"
print_section "User" "$USR_UNITS"
