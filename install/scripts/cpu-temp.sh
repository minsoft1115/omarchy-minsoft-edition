#!/usr/bin/env bash
# CPU core temperature average for Waybar (auto-detect core sensors)
# - Prefer per-core labels; fallback to package/Tctl/Tdie; finally any temp*_input
# - Outputs JSON for Waybar custom module
# Ref: Waybar temperature module options and hwmon path discovery[9][12]

set -euo pipefail

# 1) Find CPU hwmon by name (Intel: coretemp, AMD: k10temp, etc.)
HWMON=""
for d in /sys/class/hwmon/hwmon*; do
  [ -e "$d/name" ] || continue
  name=$(<"$d/name")
  case "$name" in
  coretemp | k10temp | amd_tctl | k10temp-pci-* | *cpu* | *zen*)
    HWMON="$d"
    break
    ;;
  esac
done

if [ -z "${HWMON:-}" ]; then
  printf '{"text":"  N/A","class":"low","tooltip":"CPU hwmon not found"}\n'
  exit 0
fi

# 2) Collect per-core inputs
core_inputs=()
for lf in "$HWMON"/temp*_label; do
  [ -e "$lf" ] || continue
  lbl=$(<"$lf")
  case "$lbl" in
  [Cc]ore* | CPU\ Core* | core\ [0-9]*)
    base="${lf%_label}"
    input="${base}_input"
    [ -r "$input" ] && core_inputs+=("$input")
    ;;
  esac
done

# Also prep a package/Tctl/Tdie candidate for fallback
preferred_regex='(tdie|tctl|package|cpu|Tdie|Tctl|Package)'
pkg_label_file=$(ls "$HWMON"/temp*_label 2>/dev/null | grep -Ei "$preferred_regex" | head -n1 || true)
pkg_input_file=""
[ -n "${pkg_label_file:-}" ] && pkg_input_file="${pkg_label_file%_label}_input"

# 3) Compute temperature in milli-Celsius
temp_mC=0
source_desc=""
if [ ${#core_inputs[@]} -gt 0 ]; then
  sum=0
  count=0
  for f in "${core_inputs[@]}"; do
    v=$(cat "$f" 2>/dev/null || echo 0)
    sum=$((sum + v))
    count=$((count + 1))
  done
  [ "$count" -gt 0 ] || count=1
  temp_mC=$((sum / count))
  source_desc="Avg of ${count} cores"
elif [ -n "${pkg_input_file:-}" ]; then
  temp_mC=$(cat "$pkg_input_file" 2>/dev/null || echo 0)
  source_desc="$(basename "$pkg_input_file")"
else
  fallback=$(ls "$HWMON"/temp*_input 2>/dev/null | head -n1 || true)
  if [ -n "${fallback:-}" ]; then
    temp_mC=$(cat "$fallback" 2>/dev/null || echo 0)
    source_desc="$(basename "$fallback")"
  else
    printf '{"text":"  N/A","class":"low","tooltip":"No temp inputs"}\n'
    exit 0
  fi
fi

temp=$((temp_mC / 1000))

# 4) Icon & class
icon=" "

klass="low"
if [ "$temp" -ge 90 ]; then
  klass="critical"
elif [ "$temp" -ge 80 ]; then
  klass="high"
elif [ "$temp" -ge 60 ]; then
  klass="medium"
elif [ "$temp" -ge 40 ]; then
  klass="low"
fi

# 5) Tooltip extras: show package and max core if available
# Recompute core stats for tooltip if we had cores
core_avg_text="N/A"
core_max_text="N/A"
if [ ${#core_inputs[@]} -gt 0 ]; then
  sum=0
  count=0
  max=0
  for f in "${core_inputs[@]}"; do
    v=$(cat "$f" 2>/dev/null || echo 0)
    sum=$((sum + v))
    count=$((count + 1))
    [ "$v" -gt "$max" ] && max="$v"
  done
  avg_mC=$((sum / (count > 0 ? count : 1)))
  core_avg_text="$((avg_mC / 1000))°C"
  core_max_text="$((max / 1000))°C"
fi

pkg_text="N/A"
if [ -n "${pkg_input_file:-}" ]; then
  v=$(cat "$pkg_input_file" 2>/dev/null || echo 0)
  pkg_text="$((v / 1000))°C"
fi

printf '{"text":"%s","class":"%s","tooltip":"CPU: %d°C (%s)\\nCores avg: %s, Max: %s\\nPkg: %s"}\n' \
  "$icon" "$klass" "$temp" "$source_desc" "$core_avg_text" "$core_max_text" "$pkg_text"
