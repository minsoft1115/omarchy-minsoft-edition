#!/usr/bin/bash

add_line_if_not_exists() {
  local file="$1"
  local line="$2"

  # 파일에 문자열이 없으면 추가
  if ! grep -Fxq "$line" "$file"; then
    echo "$line" >>"$file"
  fi
}

print_in_box() {
  local text="$1"
  local length=${#text}
  local border

  # 상단, 하단 테두리 생성 (텍스트 길이 + 좌우 2칸 여백)
  border=$(printf '%*s' $((length + 4)) '' | tr ' ' '=')

  echo "$border"
  echo "$text"
  echo "$border"
}

mkdir $HOME/.config/minsoft1115
mkdir $HOME/.config/minsoft1115/scripts
mkdir $HOME/.config/systemd/user

cd install

# install advcpmv
print_in_box "install advcpmv"
./install-advcpmv.sh
echo "continue ..."
read

# install kitty
#print_in_box "install kitty"
#./install-kitty.sh
#echo "continue ..."
#read

# install zsh & oh my zsh & zsh plugins
print_in_box "install zsh & oh my zsh & zsh plugins"
./install-zsh.sh
echo "continue ..."
read

# install browsers
print_in_box "install browsers"
./install-browsers.sh
echo "continue ..."
read

# install hangul (fcitx5)
print_in_box "install hangul (fcitx5)"
./install-hangul.sh
echo "continue ..."
read

# install bluetooth
print_in_box "install bluetooth"
./install-bluetooth.sh
echo "continue ..."
read

# install fastfetch
print_in_box "install fastfetch"
./install-fastfetch.sh
echo "continue ..."
read

# install lazyvim plugins
print_in_box "install lazyvim plugins"
./install-lazyvim-plugins.sh
echo "continue ..."
read

# install waybar configurations
print_in_box "install waybar configurations"
./install-waybar.sh
echo "continue ..."
read

# install starship
print_in_box "install starship"
./install-starship.sh
echo "continue ..."
read

# install hyprland
print_in_box "install hyprland configurations"
./install-hypr.sh
echo "continue ..."
read
