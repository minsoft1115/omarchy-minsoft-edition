sudo pacman -S flakpak --neended --noconfirm

cp /etc/profile.d/flatpak.sh $HOME/.config/minsoft1115
$HOME/.config/minsoft1115/flatpak.sh

mkdir $HOME/.local/share/flatpak/exports
mkdir $HOME/.local/share/flatpak/exports/share
export XDG_DATA_DIRS="$HOME/.local/share/flatpak/exports/share:${XDG_DATA_DIRS}"

flatpak install flathub io.github.qwersyk.Newelle
#flatpak run --talk-name=org.freedesktop.Flatpak --filesystem=home io.github.qwersyk.Newelle

mkdir $HOME/.config/minsoft1115/sidepad
cp -r ./sidepad/pads $HOME/.config/minsoft1115/sidepad
cp ./sidepad/sidepad $HOME/.config/minsoft1115/sidepad
cp ./sidepad/sidepad.sh $HOME/.config/minsoft1115/scripts

# newelle 에서 gemini 연결시 apikey 필요
# https://aistudio.google.com/apikey
