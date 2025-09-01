#!/usr/bin/bash

sudo pacman -S zsh --needed --noconfirm

curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sh -s -- --unattended
#sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

sudo pacman -S zoxide fzf fd bat --needed --noconfirm

git clone https://github.com/Aloxaf/fzf-tab ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fzf-tab
git clone https://github.com/wfxr/forgit ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/forgit
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-completions

git clone https://github.com/romkatv/gitstatus.git

./gitstatus/build -w -s -d docker

mv ./gitstatus $HOME

sudo pacman -S git-delta --needed --noconfirm

mkdir $HOME/.config/minsoft1115/zsh
cp ./zsh/*.zsh $HOME/.config/minsoft1115/zsh
cp ./zsh/.zshrc $HOME
