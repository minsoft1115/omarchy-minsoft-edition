#!/usr/bin/bash

add_line_if_not_exists() {
  local file="$1"
  local line="$2"

  # 파일에 문자열이 없으면 추가
  if ! grep -Fxq "$line" "$file"; then
    echo "$line" >>"$file"
  fi
}

yay -S neohtop --needed
sudo pacman -S swaync --needed

cp ./scripts/aur-status.sh $HOME/.config/minsoft1115/scripts
cp ./scripts/cpu-temp.sh $HOME/.config/minsoft1115/scripts
cp ./scripts/disk-usage.sh $HOME/.config/minsoft1115/scripts
cp ./scripts/memory-gauge-waybar.sh $HOME/.config/minsoft1115/scripts
cp ./scripts/hypr-scales-current.sh $HOME/.config/minsoft1115/scripts
cp ./scripts/hypr-scales-menu.sh $HOME/.config/minsoft1115/scripts
cp ./scripts/show-failed-units.sh $HOME/.config/minsoft1115/scripts
cp ./scripts/vpn-status.sh $HOME/.config/minsoft1115/scripts

WAYBAR_CONFIG_FILE=$HOME/.config/waybar/config.jsonc

cp $WAYBAR_CONFIG_FILE "$WAYBAR_CONFIG_FILE.bak"

json_data=$(cat "$WAYBAR_CONFIG_FILE")

json_data=$(echo "$json_data" | jq --slurpfile b ./waybar/battery.json '.battery = $b[0].battery')
json_data=$(echo "$json_data" | jq --slurpfile b ./waybar/bluetooth.json '.bluetooth = $b[0].bluetooth')
json_data=$(echo "$json_data" | jq --slurpfile b ./waybar/cpu.json '.cpu = $b[0].cpu')
json_data=$(echo "$json_data" | jq --slurpfile b ./waybar/custom-aur.json '."custom/aur" = $b[0]."custom/aur"')
json_data=$(echo "$json_data" | jq --slurpfile b ./waybar/custom-cpu-temp.json '."custom/cpu-temp" = $b[0]."custom/cpu-temp"')
json_data=$(echo "$json_data" | jq --slurpfile b ./waybar/custom-disk.json '."custom/disk" = $b[0]."custom/disk"')
json_data=$(echo "$json_data" | jq --slurpfile b ./waybar/custom-memory.json '."custom/memory" = $b[0]."custom/memory"')
json_data=$(echo "$json_data" | jq --slurpfile b ./waybar/custom-scale-change.json '."custom/scale-change" = $b[0]."custom/scale-change"')
json_data=$(echo "$json_data" | jq --slurpfile b ./waybar/custom-separator.json '."custom/separator" = $b[0]."custom/separator"')
json_data=$(echo "$json_data" | jq --slurpfile b ./waybar/custom-separator2.json '."custom/separator2" = $b[0]."custom/separator2"')
json_data=$(echo "$json_data" | jq --slurpfile b ./waybar/custom-systemd-failed-units.json '."custom/systemd-failed-units" = $b[0]."custom/systemd-failed-units"')
json_data=$(echo "$json_data" | jq --slurpfile b ./waybar/custom-vpn.json '."custom/vpn" = $b[0]."custom/vpn"')
json_data=$(echo "$json_data" | jq --slurpfile b ./waybar/hyprland-workspaces.json '."hyprland/workspaces" = $b[0]."hyprland/workspaces"')
json_data=$(echo "$json_data" | jq --slurpfile b ./waybar/memory.json '.memory = $b[0].memory')
json_data=$(echo "$json_data" | jq --slurpfile b ./waybar/cpu.json '.cpu = $b[0].cpu')
json_data=$(echo "$json_data" | jq --slurpfile b ./waybar/network-eth.json '."network#eth" = $b[0]."network#eth"')
json_data=$(echo "$json_data" | jq --slurpfile b ./waybar/network-wifi.json '."network#wifi" = $b[0]."network#wifi"')
json_data=$(echo "$json_data" | jq --slurpfile b ./waybar/power-profiles-daemon.json '."power-profiles-daemon" = $b[0]."power-profiles-daemon"')
json_data=$(echo "$json_data" | jq --slurpfile b ./waybar/pulseaudio.json '.pulseaudio = $b[0].pulseaudio')
json_data=$(echo "$json_data" | jq --slurpfile b ./waybar/user.json '.user = $b[0].user')
json_data=$(echo "$json_data" | jq --slurpfile b ./waybar/custom-swaync.json '."custom/swaync" = $b[0]."custom/swaync"')
json_data=$(echo "$json_data" | jq --slurpfile b ./waybar/modules-left.json '."modules-left" = $b[0]."modules-left"')
json_data=$(echo "$json_data" | jq --slurpfile b ./waybar/modules-center.json '."modules-center" = $b[0]."modules-center"')
json_data=$(echo "$json_data" | jq --slurpfile b ./waybar/modules-right.json '."modules-right" = $b[0]."modules-right"')

echo "$json_data" >$WAYBAR_CONFIG_FILE

mkdir $HOME/.config/minsoft1115/waybar
cp ./waybar/style-minsoft1115.css $HOME/.config/minsoft1115/waybar

mkdir $HOME/.config/swaync/
cp ./swaync/* $HOME/.config/swaync/

add_line_if_not_exists $HOME/.config/waybar/style.css '@import "../minsoft1115/waybar/style-minsoft1115.css";'

$HOME/.local/share/omarchy/default/hypr/autostart.conf

DEFAULT_AUTOSTART_FILE="${HOME}/.local/share/omarchy/default/hypr/autostart.conf"

# 백업 생성
cp -a -- "$DEFAULT_AUTOSTART_FILE" "${DEFAULT_AUTOSTART_FILE}.bak"

# 주석처리: 이미 # 로 시작하는 라인은 건드리지 않음
# 정확히 해당 라인을 찾되, 앞쪽 공백 허용
# 예) "exec-once = uwsm app -- mako" -> "# exec-once = uwsm app -- mako"
sed -i -E '/^[[:space:]]*#/! s/^[[:space:]]*exec-once[[:space:]]*=[[:space:]]*uwsm[[:space:]]+app[[:space:]]*--[[:space:]]*mako([[:space:]].*)?$/# &/' "$DEFAULT_AUTOSTART_FILE"
