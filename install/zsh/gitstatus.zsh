source "$HOME/gitstatus/gitstatus.plugin.zsh"

gitstatus_stop "git_summary_$$"
gitstatus_start "git_summary_$$"

git-summary() {
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
