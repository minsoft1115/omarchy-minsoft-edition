#!/bin/bash

# 필요 시 PATH 보강 (원본 유지)
export PATH="$HOME/.local/share/omarchy/bin:$PATH"

# 공용 메뉴 함수 (원본 구조 유지, theme는 필요 시 조정 가능)
menu() {
  local prompt="$1"
  local options="$2"
  local extra="$3"
  local preselect="$4"

  read -r -a args <<<"$extra"

  if [[ -n "$preselect" ]]; then
    local index
    index=$(echo -e "$options" | grep -nxF "$preselect" | cut -d: -f1)
    if [[ -n "$index" ]]; then
      args+=("-a" "$index")
    fi
  fi

  echo -e "$options" | walker --dmenu --theme dmenu_250 -p "$prompt…" "${args[@]}"
}

# 스크린샷 메뉴만 제공
show_screenshot_menu() {
  case $(menu "Screenshot" "  Region\n  Window\n  Display") in
  *Region*) omarchy-cmd-screenshot ;;
  *Window*) omarchy-cmd-screenshot window ;;
  *Display*) omarchy-cmd-screenshot output ;;
  esac
}

# 엔트리포인트: 바로 스크린샷 메뉴만 띄움
show_screenshot_menu
