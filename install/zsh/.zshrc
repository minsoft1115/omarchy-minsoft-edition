export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME=""

DISABLE_UNTRACKED_FILES_DIRTY="true"

plugins=(
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-completions
  zoxide                  # zoxide ('z' 명령어로 스마트하게 디렉토리 이동)
  fzf                     # fzf 기본 기능 및 키바인딩 (Ctrl-T, Ctrl-R, Alt-C)
  fzf-tab                 # fzf를 이용한 자동완성 기능 (매우 중요)
  forgit                  # fzf를 이용한 대화형 git 명령어
)

source $ZSH/oh-my-zsh.sh

alias ls='eza --icons=always --git --color=auto --group-directories-first'
alias ll='eza -l --icons=always --git --color=auto --group-directories-first -h'
alias la='eza -a --icons=always --git --color=auto --group-directories-first -h'
alias lt='eza --tree --icons=always --git --color=auto --group-directories-first'
alias ip='ip --color=auto'
alias ssh='TERM=xterm ssh'
alias diff='f() { diff -u "$1" "$2" | delta; }; f'
alias cp='advcp -g'
alias mv='advmv -g'


source $HOME/.config/minsoft1115/zsh/fzf.zsh
source $HOME/.config/minsoft1115/zsh/gitstatus.zsh

if [[ "$TERM" == "linux" ]]; then
  ZSH_AUTOSUGGEST_HISTORY_IGNORE="*" 

  export STARSHIP_CONFIG=$HOME/.config/minsoft1115/starship/starship-tty.toml
else
  export STARSHIP_CONFIG=$HOME/.config/starship.toml
fi

eval "$(starship init zsh)"


# ----------------------------------------------------------------------------


if ! [[ -z $DISPLAY && $XDG_VTNR -eq 1 ]]; then
    command -v fastfetch >/dev/null && fastfetch -c $HOME/.config/minsoft1115/fastfetch/config-minsoft1115.jsonc
fi
