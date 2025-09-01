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

