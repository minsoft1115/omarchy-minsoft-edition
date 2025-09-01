#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/share/omarchy/bin:$PATH"

# -------------------------
# 메뉴 항목 정의
# -------------------------
# 화면에 표시될 메뉴 목록입니다.
MENU_ITEMS=(
  " Lock"
  "󰍃 Logout"
  " Suspend"
  "󰒲 Hibernate"
  "󰜉 Reboot"
  "󰐥 Shutdown"
)

# -------------------------
# Walker 실행 및 선택
# -------------------------
# walker를 dmenu 모드로 실행.
# -p: 프롬프트 텍스트 설정
# -w: 창 너비(width) 설정 (px 단위)
# <<< "${MENU_ITEMS[@]}" : 배열을 표준 입력으로 전달
CHOICE=$(printf "%s\n" "${MENU_ITEMS[@]}" |
  walker --dmenu -p "Power:" -w 320) || exit 0

# -------------------------
# 선택에 따른 명령어 실행
# -------------------------
case "${CHOICE#* }" in
"Lock")
  omarchy-lock-screen
  ;;
"Logout")
  hyprctl dispatch exit
  ;;
"Suspend")
  systemctl suspend
  ;;
"Hibernate")
  systemctl hibernate
  ;;
"Reboot")
  systemctl reboot
  ;;
"Shutdown")
  systemctl poweroff
  ;;
*) # 사용자가 아무것도 선택하지 않거나 Esc를 누르면 스크립트를 종료합니다.
  exit 0
  ;;
esac
