#!/bin/bash

# Convert bytes to GiB
gib() { awk -v b=$1 'BEGIN{printf "%.2f", b/1073741824}'; }
░ ▒ ▓
# Progress bar (20 blocks)
bar_len=20
make_bar() {
  local used=$1 total=$2
  local percent=0
  ((total > 0)) && percent=$((used * 100 / total))
  local bar_len=20

  # 칸수는 올림 사용
  local used_blocks=$(((percent + 4) / 5)) # ceil(percent/5) 효과
  if ((used_blocks > bar_len)); then
    used_blocks=$bar_len
  fi

  local free_blocks=$((bar_len - used_blocks))

  local bar=$(printf "%0.s▓" $(seq 1 $used_blocks))
  bar+=$(printf "%0.s░" $(seq 1 $free_blocks))
  printf "%s %d%% (%s / %s)" \
    "$bar" "$percent" "$(gib "$used")GiB" "$(gib "$total")GiB"
}

declare -A seen
tooltip_lines=()
total_sum=0
used_sum=0
free_sum=0
reserved_sum=0

# Iterate mounts
while read -r src fstype size usedb availb _; do
  # Clean up btrfs form like: /dev/mapper/root[/@]
  devpath=$(echo "$src" | sed 's/\[.*//')
  devname=$(basename "$devpath")

  # Fallback: skip if not a block device
  if ! lsblk -no NAME "$devpath" &>/dev/null; then
    continue
  fi

  [[ -n "${seen[$devname]}" ]] && continue
  seen[$devname]=1

  reserved=$((size - usedb - availb))
  ((reserved < 0)) && reserved=0

  total_sum=$((total_sum + size))
  used_sum=$((used_sum + usedb))
  free_sum=$((free_sum + availb))
  reserved_sum=$((reserved_sum + reserved))

  line="$devpath: $(gib ${availb})GiB Free
    $(make_bar $usedb $size)"
  tooltip_lines+=("$line")

done < <(findmnt -b -o SOURCE,FSTYPE,SIZE,USED,AVAIL,USE%,TARGET)

# Add Total summary
total_line="Total: $(gib ${free_sum})GiB Free
    $(make_bar $used_sum $total_sum)"
tooltip_lines+=("$total_line")

# Format tooltip for JSON
tooltip=$(printf "%s\n" "${tooltip_lines[@]}")
tooltip=${tooltip//$'\n'/\\n}
tooltip_escaped=${tooltip//\"/\\\"}

# Output JSON
printf '{"text": "󰋊 %sG Free", "class": "tooltip", "tooltip": "%s"}\n' \
  "$(gib $free_sum)" "$tooltip_escaped"
