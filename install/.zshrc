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
alias hyprland='$HOME/start-hyprland.sh'


# -----------------------------------------------------------------------------
# FZF config
# -----------------------------------------------------------------------------

if (( $+commands[eza] )); then
    alias ls='eza --color=auto --icons --group-directories-first'
    alias l='ls -lhF'
    alias la='ls -lhAF'
    alias tree='ls --tree'
fi

if (( $+commands[zoxide] )); then
    eval "$(zoxide init zsh)"
    export _ZO_FZF_OPTS="--preview '(eza --tree --icons --level 3 {2} || tree -NC {2}) 2>/dev/null | head -200'"
fi

export FZF_DEFAULT_COMMAND="rg --files --hidden --follow --glob '!.git' --no-ignore || find ."

export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

export FZF_DEFAULT_OPTS='--height 40% --tmux 100%,60% --border=sharp'

export FZF_CTRL_T_OPTS="--preview '(bat --style=numbers --color=always {} || \
                       cat {} || tree -NC {}) 2>/dev/null | head -200' \
                       --preview-window=right,60%,border-sharp"

export FZF_CTRL_R_OPTS="--preview 'echo {}' \
                       --preview-window=down:3:hidden:wrap:border-sharp \
                       --bind '?:toggle-preview' --exact"

export FZF_ALT_C_OPTS="--preview '(eza --tree --icons --level 3 --color=always --group-directories-first {} || \
                       tree -NC {} || ls --color=always --group-directories-first {}) 2>/dev/null | head -200' \
                       --preview-window=right,60%,border-sharp"


zstyle ':completion:*' menu no
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:complete:*:options' sort false
zstyle ':fzf-tab:*' switch-group '<' '>'

zstyle ':fzf-tab:complete:git-(add|diff|restore):*' fzf-preview \
	   'git diff $word | delta'
zstyle ':fzf-tab:complete:git-log:*' fzf-preview \
	   'git log --color=always $word'
zstyle ':fzf-tab:complete:git-help:*' fzf-preview \
	   'git help $word | bat -plman --color=always'
zstyle ':fzf-tab:complete:git-show:*' fzf-preview \
	   'case "$group" in
	"commit tag") git show --color=always $word ;;
	*) git show --color=always $word | delta ;;
	esac'
zstyle ':completion:*:git-checkout:*' sort false
zstyle ':fzf-tab:complete:git-checkout:*' fzf-preview \
	   'case "$group" in
	"modified file") git diff $word | delta ;;
	"recent commit object name") git show --color=always $word | delta ;;
	*) git log --color=always $word ;;
	esac'

zstyle ':fzf-tab:complete:(\\|*/|)man:*' fzf-preview 'man $word | bat -plman --color=always'
zstyle ':fzf-tab:complete:tldr:argument-1' fzf-preview 'tldr --color always $word'

fbr() {
  local branches branch
  branches=$(git branch --all | grep -v HEAD) &&
  branch=$(echo "$branches" | fzf-tmux -p 80% -- --reverse) &&
  git checkout $(echo "$branch" | sed "s/.* //" | sed "s#remotes/origin/##")
}

zle -N fbr

bindkey '^B' fbr



# --------------------------------------------------------------------
# Git Summary 기능 (최종 완성본 - 무조건 데몬 실행)
# --------------------------------------------------------------------

# [1] gitstatus 플러그인 로드 (가장 먼저 실행)
source "$HOME/gitstatus/gitstatus.plugin.zsh"

# [2] Zsh 시작 시, 각 터미널 세션마다 고유한 데몬을 무조건 시작합니다.
# 이 데몬은 터미널이 종료될 때 자동으로 함께 종료됩니다.
gitstatus_stop "git_summary_$$"
gitstatus_start "git_summary_$$"

# [11] Git 상태를 요약해서 보여주는 메인 함수
git-summary() {
  # --- 데몬 ID 설정 및 Git 저장소 확인 ---
  local GITSTATUS_ID="git_summary_$$"
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "This is not a Git repository." >&2
    return 1
  fi

  # [핵심] 데몬이 항상 실행 중이라고 가정하고, 확인 절차 없이 바로 쿼리합니다.
  gitstatus_query "$GITSTATUS_ID"

  # --- Git 상태 변수 추출 ---
  local branch ahead behind staged conflicted unstaged untracked stashed
  branch="${VCS_STATUS_LOCAL_BRANCH:-@${VCS_STATUS_COMMIT:0:7}}"
  ahead=$VCS_STATUS_AHEAD behind=$VCS_STATUS_BEHIND staged=$VCS_STATUS_NUM_STAGED
  conflicted=$VCS_STATUS_NUM_CONFLICTED unstaged=$VCS_STATUS_NUM_UNSTAGED
  untracked=$VCS_STATUS_NUM_UNTRACKED stashed=$VCS_STATUS_NUM_STASHED

  # --- ANSI 이스케이프 코드 및 아이콘 정의 ---
  local c_reset='\e[0m' c_bold='\e[1m' c_nobold='\e[22m'
  local c_branch_clean='\e[32m' c_branch_modified='\e[31m' c_branch_sync='\e[33m'
  local c_dim='\e[2m' c_ahead_behind='\e[36m' c_staged='\e[32m'
  local c_conflicted='\e[35m' c_unstaged='\e[33m' c_untracked='\e[34m' c_stashed='\e[34m'

  local icon_ahead='󰁝' icon_behind='󰁅' icon_staged='' icon_conflicted='󰊛'
  local icon_unstaged='' icon_untracked='' icon_stashed=''

  # --- 브랜치 및 구분선 출력 ---
  local branch_label="branch"
  local line_length=$(( ${#branch_label} + 5 + ${#branch} ))

  local branch_color
  if (( staged > 0 || unstaged > 0 || conflicted > 0 || untracked > 0 )); then
    branch_color=$c_branch_modified
  elif (( ahead > 0 || behind > 0 )); then
    branch_color=$c_branch_sync
  else
    branch_color=$c_branch_clean
  fi
  print "${c_bold}${branch_label}${c_nobold} : ${branch_color}${c_bold}${branch}${c_nobold}${c_reset}"
  local separator=${(l:line_length::--:)}
  print "${c_dim}${separator}${c_reset}"

  # --- 각 상태 라인을 printf로 직접 출력 ---
  printf "%b%s%b %-10s : %b%s%b\n" "$c_ahead_behind" "$icon_ahead" "$c_reset" "ahead" "$c_bold" "${ahead:-0}" "$c_nobold$c_reset"
  printf "%b%s%b %-10s : %b%s%b\n" "$c_ahead_behind" "$icon_behind" "$c_reset" "behind" "$c_bold" "${behind:-0}" "$c_nobold$c_reset"
  printf "%b%s%b %-10s : %b%s%b\n" "$c_staged" "$icon_staged" "$c_reset" "staged" "$c_bold" "${staged:-0}" "$c_nobold$c_reset"
  printf "%b%s%b %-10s : %b%s%b\n" "$c_conflicted" "$icon_conflicted" "$c_reset" "conflicted" "$c_bold" "${conflicted:-0}" "$c_nobold$c_reset"
  printf "%b%s%b %-10s : %b%s%b\n" "$c_unstaged" "$icon_unstaged" "$c_reset" "unstaged" "$c_bold" "${unstaged:-0}" "$c_nobold$c_reset"
  printf "%b%s%b %-10s : %b%s%b\n" "$c_untracked" "$icon_untracked" "$c_reset" "untracked" "$c_bold" "${untracked:-0}" "$c_nobold$c_reset"
  printf "%b%s%b %-10s : %b%s%b\n" "$c_stashed" "$icon_stashed" "$c_reset" "stashed" "$c_bold" "${stashed:-0}" "$c_nobold$c_reset"
}
# --------------------------------------------------------------------

if [[ "$TERM" == "linux" ]]; then
  # 이 변수를 설정하면 플러그인이 로드되더라도 작동하지 않습니다.
  ZSH_AUTOSUGGEST_HISTORY_IGNORE="*" 

  export STARSHIP_CONFIG=~/.config/starship-tty.toml
else
  export STARSHIP_CONFIG=~/.config/starship.toml
fi

eval "$(starship init zsh)"


# ----------------------------------------------------------------------------
export PATH=$PATH:/home/lmh/.local/share/omarchy/bin


if [[ -z $DISPLAY && $XDG_VTNR -eq 1 ]]; then
    clear
#    cat ~/.config/omarchy-logo
#    command -v fastfetch >/dev/null && fastfetch --config /usr/share/fastfetch/presets/all.jsonc
#    exec hyprland > /tmp/hyprland.log 2>&1
else
    command -v fastfetch >/dev/null && fastfetch
fi
