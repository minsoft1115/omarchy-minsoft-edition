#!/usr/bin/bash

sudo pacman -S kitty --needed --noconfirm
sudo pacman -S ttf-jetbrains-mono-nerd --needed --noconfirm

cp -r ./kitty $HOME/.config
