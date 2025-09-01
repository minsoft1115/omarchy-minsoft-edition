#!/usr/bin/bash

sudo pacman -S qutebrowser firefox --needed --noconfirm
sudo pacman -S xorg-xrdb --needed --noconfirm

cat >~/.Xresources <<'EOF'
*.background: #000000
*.foreground: #ffffff
*.color0: #000000
*.color1: #cd0000
*.color2: #00cd00
*.color3: #cdcd00
*.color4: #0000ee
*.color5: #cd00cd
*.color6: #00cdcd
*.color7: #e5e5e5
*.color8: #7f7f7f
*.color9: #ff0000
*.color10: #00ff00
*.color11: #ffff00
*.color12: #5c5cff
*.color13: #ff00ff
*.color14: #00ffff
*.color15: #ffffff
EOF

xrdb -merge ~/.Xresources

cp -r ./qutebrowser/ $HOME/.config
