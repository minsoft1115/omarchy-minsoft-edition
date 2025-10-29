#!/bin/bash

gib() { awk -v b=$1 'BEGIN{printf "%.2f", b/1024/1024}'; }

bar_len=20
make_bar() {
  local used=$1 total=$2
  local percent=0
  ((total > 0)) && percent=$((used * 100 / total))

  local used_blocks=$(((percent + 4) / 5))
  ((used_blocks > bar_len)) && used_blocks=$bar_len
  local free_blocks=$((bar_len - used_blocks))

  local bar=$(printf "%0.s▓" $(seq 1 $used_blocks))
  bar+=$(printf "%0.s░" $(seq 1 $free_blocks))

  printf "%s %d%% (%s / %s)" \
    "$bar" "$percent" "$(gib $used)GiB" "$(gib $total)GiB"
}

# /proc/meminfo에서 총 메모리와 사용 가능 메모리 추출
read total available < <(awk '
/MemTotal/ {total=$2}
/MemAvailable/ {available=$2}
END {print total, available}
' /proc/meminfo)

used=$((total - available))

# JSON 출력용 변수
text=$(printf " %.1fG Free" "$(gib $available)")
tooltip=$(make_bar $used $total)

# Waybar에 보낼 JSON 출력
jq -c -n --arg text "$text" --arg tooltip "$tooltip" '{text: $text, tooltip: $tooltip}'
