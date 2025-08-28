#!/bin/bash

# 노트북 내장 디스플레이 이름 (hyprctl monitors로 확인)
INTERNAL_DISPLAY="eDP-1"

# 덮개 상태 파일의 경로를 동적으로 찾기
# find 명령으로 state 파일을 찾고, 첫 번째 결과를 사용
LID_STATE_PATH=$(find /proc/acpi/button/lid -type f -name "state" | head -n 1)

# 덮개 상태 파일을 찾았는지 확인
if [ -z "$LID_STATE_PATH" ]; then
  # 파일을 찾지 못하면 스크립트 종료 (오류 방지)
  exit 0
fi

# 외부 모니터가 연결되어 있는지 확인
if hyprctl monitors | grep -v "$INTERNAL_DISPLAY" | grep -q "Monitor"; then
  # 덮개가 닫혀 있는지 확인 (동적으로 찾은 경로 사용)
  if grep -q "closed" "$LID_STATE_PATH"; then
    # 내장 디스플레이 비활성화
    hyprctl keyword monitor "$INTERNAL_DISPLAY, disable"
  fi
fi
