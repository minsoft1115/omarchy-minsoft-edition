#!/usr/bin/bash

sudo pacman -S bluetui --needed --noconfirm
sudo pacman -S python-dbus-next --needed --noconfirm

mkdir $HOME/.local/systemd/user

systemctl --user stop bt-notify-dbus.service
systemctl --user disable bt-notify-dbus.service

cp ./scripts/bt-notify-dbus.py $HOME/.config/minsoft1115/scripts
cp ./systemd/bt-notify-dbus.service $HOME/.config/systemd/user

chmod +x $HOME/.config/minsoft1115/scripts/bt-notify-dbus.py

systemctl --user daemon-reload
systemctl --user enable --now bt-notify-dbus.service
