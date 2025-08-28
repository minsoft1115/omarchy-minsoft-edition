# gitstatus 바인딩 로드 및 데몬 시작(세션 고유 ID 사용)
source "$HOME/gitstatus/gitstatus.plugin.zsh"
gitstatus_stop "git_summary_$$" 2>/dev/null
gitstatus_start "git_summary_$$"

# git-summary: gitstatus 데몬에서 상태 수집 → 포맷 출력
git-summary() {
  # 함수 안에서만 옵션/환경 변경이 적용되도록 로컬 옵션 사용
  setopt local_options err_return no_unset typeset_silent
  emulate -L zsh

  # 색상/아이콘 설정 (Nerd Font 환경 가정, 필요 시 I_* 변경)
  local RESET=$'\e[0m'
  local C_ICON_BRANCH=$'\e[38;5;45m'
  local C_ICON_UNSTAGED=$'\e[38;5;178m'
  local C_ICON_WTMOD=$'\e[38;5;178m'
  local C_ICON_WTDEL=$'\e[38;5;196m'   # 삭제: 붉은색
  local C_ICON_UNTRACKED=$'\e[38;5;39m'
  local C_ICON_STAGED=$'\e[38;5;82m'
  local C_ICON_CONFLICT=$'\e[38;5;196m'
  local C_ICON_STASH=$'\e[38;5;214m'
  local C_ICON_AHEAD=$'\e[38;5;70m'
  local C_ICON_BEHIND=$'\e[38;5;203m'
  local C_NUM=$'\e[38;5;39m'   # 숫자만 이 색 적용

  # 아이콘 (Nerd Font)
  local I_BRANCH="" I_AHEAD="󰁝" I_BEHIND="󰁅" I_STAGED="" I_CONFLICT="󰊛" I_UNSTAGED="" I_WTMOD="" I_WTDEL="" I_UNTRACKED="" I_STASH=""

  # Git 저장소 여부 확인
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf "%s\n" "Not inside a Git repository."
    return 1
  fi

  # gitstatus 데몬 쿼리 (동기)
  if ! gitstatus_query "git_summary_$$" >/dev/null 2>&1; then
    printf "%s\n" "gitstatus daemon unavailable."
    return 1
  fi

  # 브랜치/동기화 정보 (데몬 변수 사용)
  local branch="${VCS_STATUS_LOCAL_BRANCH:-@${VCS_STATUS_COMMIT:0:7}}"
  local ahead=${VCS_STATUS_COMMITS_AHEAD:-0}
  local behind=${VCS_STATUS_COMMITS_BEHIND:-0}

  # 파일 상태 카운트 (데몬 변수 사용)
  local staged=${VCS_STATUS_NUM_STAGED:-0}
  local unstaged=${VCS_STATUS_NUM_UNSTAGED:-0}
  local untracked=${VCS_STATUS_NUM_UNTRACKED:-0}
  local conflicted=${VCS_STATUS_NUM_CONFLICTED:-0}
  local stashed=${VCS_STATUS_STASHES:-0}

  # Worktree 세부: 삭제(wt_del), 수정만(wt_mod)
  local wt_del=${VCS_STATUS_NUM_UNSTAGED_DELETED:-0}
  local wt_mod=$(( unstaged - wt_del ))
  (( wt_mod < 0 )) && wt_mod=0

  # 라인 데이터(평문) 보관용 배열
  typeset -a T_TREE T_ICON T_LABEL T_VPRE T_NUM T_VSUF T_KIND
  local __n=0

  # 1) 브랜치
  __n=$((__n+1))
  T_TREE[__n]=""         ; T_ICON[__n]="$I_BRANCH"
  T_LABEL[__n]="branch"  ; T_VPRE[__n]="" ; T_NUM[__n]="" ; T_VSUF[__n]="$branch"
  T_KIND[__n]="branch"

  # 2) Worktree 섹션
  __n=$((__n+1))
  T_TREE[__n]=""         ; T_ICON[__n]="" ; T_LABEL[__n]="Worktree"
  T_VPRE[__n]=""         ; T_NUM[__n]=""  ; T_VSUF[__n]=""
  T_KIND[__n]="section"

  # 2-1) Unstaged (files)
  __n=$((__n+1))
  T_TREE[__n]="├─ "      ; T_ICON[__n]="$I_UNSTAGED" ; T_LABEL[__n]="Unstaged"
  T_VPRE[__n]=""         ; T_NUM[__n]="${unstaged}"   ; T_VSUF[__n]=" files"
  T_KIND[__n]="unstaged"

  # 2-2) wt mod (files)
  __n=$((__n+1))
  T_TREE[__n]="│  └─ "   ; T_ICON[__n]="$I_WTMOD" ; T_LABEL[__n]="wt mod"
  T_VPRE[__n]=""         ; T_NUM[__n]="${wt_mod}" ; T_VSUF[__n]=" files"
  T_KIND[__n]="wtmod"

  # 2-3) wt del (files) — 삭제는 붉은색 아이콘 컬러로 출력
  __n=$((__n+1))
  T_TREE[__n]="   └─ "   ; T_ICON[__n]="$I_WTDEL" ; T_LABEL[__n]="wt del"
  T_VPRE[__n]=""         ; T_NUM[__n]="${wt_del}" ; T_VSUF[__n]=" files"
  T_KIND[__n]="wtdel"

  # 2-4) Untracked (files)
  __n=$((__n+1))
  T_TREE[__n]="└─ "      ; T_ICON[__n]="$I_UNTRACKED" ; T_LABEL[__n]="Untracked"
  T_VPRE[__n]=""         ; T_NUM[__n]="${untracked}"  ; T_VSUF[__n]=" files"
  T_KIND[__n]="untracked"

  # 3) Index 섹션
  __n=$((__n+1))
  T_TREE[__n]=""         ; T_ICON[__n]="" ; T_LABEL[__n]="Index"
  T_VPRE[__n]=""         ; T_NUM[__n]=""  ; T_VSUF[__n]=""
  T_KIND[__n]="section"

  # 3-1) Staged (files)
  __n=$((__n+1))
  T_TREE[__n]="├─ "      ; T_ICON[__n]="$I_STAGED" ; T_LABEL[__n]="Staged"
  T_VPRE[__n]=""         ; T_NUM[__n]="${staged}"  ; T_VSUF[__n]=" files"
  T_KIND[__n]="staged"

  # 3-2) Conflicted (files)
  __n=$((__n+1))
  T_TREE[__n]="└─ "      ; T_ICON[__n]="$I_CONFLICT" ; T_LABEL[__n]="Conflicted"
  T_VPRE[__n]=""         ; T_NUM[__n]="${conflicted}" ; T_VSUF[__n]=" files"
  T_KIND[__n]="conflict"

  # 4) Repo state 섹션
  __n=$((__n+1))
  T_TREE[__n]=""         ; T_ICON[__n]="" ; T_LABEL[__n]="Repo state"
  T_VPRE[__n]=""         ; T_NUM[__n]=""  ; T_VSUF[__n]=""
  T_KIND[__n]="section"

  # 4-1) Stashed
  __n=$((__n+1))
  T_TREE[__n]="├─ "      ; T_ICON[__n]="$I_STASH" ; T_LABEL[__n]="Stashed"
  T_VPRE[__n]=""         ; T_NUM[__n]="${stashed}" ; T_VSUF[__n]=""
  T_KIND[__n]="stash"

  # 4-2) Ahead (commit count)
  __n=$((__n+1))
  T_TREE[__n]="├─ "      ; T_ICON[__n]="$I_AHEAD" ; T_LABEL[__n]="Ahead"
  T_VPRE[__n]=""         ; T_NUM[__n]="${ahead}" ; T_VSUF[__n]=""
  T_KIND[__n]="ahead"

  # 4-3) Behind (commit count)
  __n=$((__n+1))
  T_TREE[__n]="└─ "      ; T_ICON[__n]="$I_BEHIND" ; T_LABEL[__n]="Behind"
  T_VPRE[__n]=""         ; T_NUM[__n]="${behind}" ; T_VSUF[__n]=""
  T_KIND[__n]="behind"

  # 좌측 정렬 폭 계산: tree + icon(+2칸) + label
  local max_left=0 __ln __icon_gap __left_plain
  for ((__ln=1; __ln<=__n; __ln++)); do
    __icon_gap=""
    [[ -n "${T_ICON[__ln]}" ]] && __icon_gap="  "
    __left_plain="${T_TREE[__ln]}${T_ICON[__ln]}${__icon_gap}${T_LABEL[__ln]}"
    (( ${#__left_plain} > max_left )) && max_left=${#__left_plain}
  done

  # 라인 유형별 아이콘 색 선택
  icon_color_for() {
    case "$1" in
      branch)    printf "%s" "$C_ICON_BRANCH" ;;
      unstaged)  printf "%s" "$C_ICON_UNSTAGED" ;;
      wtmod)     printf "%s" "$C_ICON_WTMOD" ;;
      wtdel)     printf "%s" "$C_ICON_WTDEL" ;;    # 삭제: 붉은색
      untracked) printf "%s" "$C_ICON_UNTRACKED" ;;
      staged)    printf "%s" "$C_ICON_STAGED" ;;
      conflict)  printf "%s" "$C_ICON_CONFLICT" ;;
      stash)     printf "%s" "$C_ICON_STASH" ;;
      ahead)     printf "%s" "$C_ICON_AHEAD" ;;
      behind)    printf "%s" "$C_ICON_BEHIND" ;;
      *)         printf "%s" "" ;;
    esac
  }

  # 한 줄 렌더링(아이콘만 색, 숫자만 색)
  render_line() {
    local j="$1"
    local tree icon label kind vpre vnum vsuf
    tree="${T_TREE[$j]}"; icon="${T_ICON[$j]}"; label="${T_LABEL[$j]}"; kind="${T_KIND[$j]}"
    vpre="${T_VPRE[$j]}"; vnum="${T_NUM[$j]}"; vsuf="${T_VSUF[$j]}"

    local icon_gap=""; [[ -n "$icon" ]] && icon_gap="  "
    local left_for_width="${tree}${icon}${icon_gap}${label}"
    local padspaces=$(( max_left - ${#left_for_width} )); (( padspaces < 0 )) && padspaces=0
    local ICOLOR; ICOLOR="$(icon_color_for "$kind")"

    local has_value=0
    [[ -n "$vpre$vnum$vsuf" ]] && has_value=1

    if (( ! has_value )); then
      if [[ -n "$icon" ]]; then
        printf "%s%b%s%b%s\n" "$tree" "$ICOLOR" "$icon" "$RESET" "${icon_gap}${label}"
      else
        printf "%s%s\n" "$tree" "$label"
      fi
    else
      local sep=" : "
      if [[ -n "$icon" ]]; then
        printf "%s%b%s%b%s%*s%s" \
          "$tree" "$ICOLOR" "$icon" "$RESET" "${icon_gap}${label}" \
          "$padspaces" "" "$sep"
      else
        printf "%s%s%*s%s" \
          "$tree" "$label" \
          "$padspaces" "" "$sep"
      fi
      [[ -n "$vpre" ]] && printf "%s" "$vpre"
      [[ -n "$vnum" ]] && printf "%b%s%b" "$C_NUM" "$vnum" "$RESET"
      [[ -n "$vsuf" ]] && printf "%s" "$vsuf"
      printf "\n"
    fi
  }

  # 출력
  render_line 1
  printf "%s\n" "----------------------------------------------------"
  for ((__ln=2; __ln<=__n; __ln++)); do
    render_line "$__ln"
  done
}

