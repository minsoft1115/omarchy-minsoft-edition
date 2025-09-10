#!/usr/bin/bash

add_line_if_not_exists() {
  local file="$1"
  local line="$2"

  # 파일에 문자열이 없으면 추가
  if ! grep -Fxq "$line" "$file"; then
    echo "$line" >>"$file"
  fi
}

escape_sed_replacement() {
  printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
}

replace_text() {
  local file="$1"
  local search="$2"
  local replace="$3"

  if [[ -f "$file" ]]; then
    local esc_search=$(printf '%s' "$search" | sed -e 's/[\/&]/\\&/g')
    local esc_replace=$(escape_sed_replacement "$replace")

    sed -i "s/${esc_search}/${esc_replace}/g" "$file"
    echo "Replaced all occurrences of '${search}' with '${replace}' in $file"
  else
    echo "File $file does not exist."
  fi
}

mkdir $HOME/.config/minsoft1115/hypr

cp ./hypr/hyprland-minsoft1115.conf $HOME/.config/minsoft1115/hypr
cp ./hypr/bindings-minsoft1115.conf $HOME/.config/minsoft1115/hypr
cp ./scripts/power-menu.sh $HOME/.config/minsoft1115/scripts

sudo pacman -S gedit --needed --noconfirm
sudo pacman -S lite-xl --needed --noconfirm

cp /usr/share/applications/org.lite_xl.lite_xl.desktop $HOME/.local/share/applications/

replace_text $HOME/.local/share/applications/org.lite_xl.lite_xl.desktop "Exec=lite-xl %F" "Exec=env GDK_SCALE=1 GDK_DPI_SCALE=1 lite-xl $HOME/Documents %F"

#/usr/share/applications/org.lite_xl.lite_xl.desktop

#systemctl --user stop hyprlock-suspend.service
#systemctl --user disable hyprlock-suspend.service

cp ./scripts/hyprlock-suspend.py $HOME/.config/minsoft1115/scripts
cp ./scripts/handle-lid-switch.sh $HOME/.config/minsoft1115/scripts

add_line_if_not_exists $HOME/.config/hypr/hyprland.conf "source = ~/.config/minsoft1115/hypr/hyprland-minsoft1115.conf"

./scripts/add-or-update-key-in-section.py ~/.config/hypr/hypridle.conf "general" "ignore_systemd_inhibit" false
./scripts/add-or-update-key-in-section.py ~/.config/hypr/hypridle.conf "general" "ignore_dbus_inhibit" false

./scripts/add-or-update-key-in-section.py ~/.config/hypr/input.conf "input" "repeat_rate" 80
./scripts/add-or-update-key-in-section.py ~/.config/hypr/input.conf "input" "repeat_delay" 250
