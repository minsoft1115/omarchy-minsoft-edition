#!/usr/bin/bash

add_line_if_not_exists() {
  local file="$1"
  local line="$2"

  # 파일에 문자열이 없으면 추가
  if ! grep -Fxq "$line" "$file"; then
    echo "$line" >>"$file"
  fi
}

mkdir $HOME/.config/minsoft1115/hypr

cp ./hypr/hyprland-minsoft1115.conf $HOME/.config/minsoft1115/hypr
cp ./hypr/bindings-minsoft1115.conf $HOME/.config/minsoft1115/hypr
cp ./scripts/power-menu.sh $HOME/.config/minsoft1115/scripts

add_line_if_not_exists $HOME/.config/hypr/hyprland.conf "source = ~/.config/minsoft1115/hypr/hyprland-minsoft1115.conf"
