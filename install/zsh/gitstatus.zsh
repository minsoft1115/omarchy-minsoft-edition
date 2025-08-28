# gitstatus 바인딩 로드/데몬 시작 (세션 고유 NAME 사용)
source "$HOME/gitstatus/gitstatus.plugin.zsh"
gitstatus_stop "git_summary_$$" 2>/dev/null
gitstatus_start "git_summary_$$"

# git-summary: 데이터 먼저(평문), 렌더에서만 부분 색(아이콘/숫자), 라인당 단일 printf
git-summary() {
  setopt local_options err_return no_unset
  emulate -L zsh

  # ESC 표기는 $'\e'로 통일
  local RESET=$'\e[0m'

  # 아이콘 색(예시 팔레트 — 필요 시 조정)
  local C_ICON_BRANCH=$'\e[38;5;45m'
  local C_ICON_GROUP_UNSTAGED=$'\e[38;5;178m'
  local C_ICON_GROUP_STAGED=$'\e[38;5;82m'
  local C_ICON_MODIFIED=$'\e[38;5;178m'
  local C_ICON_DELETED=$'\e[38;5;196m'
  local C_ICON_NEW=$'\e[38;5;70m'
  local C_ICON_UNTRACKED=$'\e[38;5;39m'
  local C_ICON_CONFLICT=$'\e[38;5;196m'
  local C_ICON_STASH=$'\e[38;5;214m'
  local C_ICON_AHEAD=$'\e[38;5;70m'
  local C_ICON_BEHIND=$'\e[38;5;203m'

  # 숫자만 색
  local C_NUM=$'\e[38;5;39m'

  # 아이콘(요청 반영)
  local I_BRANCH=""
  local I_GROUP_UNSTAGED="󰘓"   # 상위 Unstaged 그룹
  local I_GROUP_STAGED="󰄬"     # 상위 Staged 그룹
  local I_MODIFIED="󰷉"        # 하위 modified
  local I_DELETED=""
  local I_NEW=""
  local I_UNTRACKED=""
  local I_CONFLICT="󰊛"
  local I_STASH=""
  local I_AHEAD="󰁝"
  local I_BEHIND="󰁅"

  # Git repo check
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf "%s\n" "Not inside a Git repository."
    return 1
  fi

  # 기본 데이터 수집
  local branch upstream ahead behind
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || printf "%s" "(detached)")"
  upstream="$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || printf "%s" "")"
  ahead=0; behind=0
  if [[ -n "$upstream" ]]; then
    local counts rest
    counts="$(git rev-list --left-right --count HEAD...$upstream 2>/dev/null)"
    ahead="${counts%%$'\t'*}"; rest="${counts#*$'\t'}"
    ahead="${ahead//[^0-9]/}"; [[ -z "$ahead" ]] && ahead=0
    behind="${rest//[^0-9]/}"; [[ -z "$behind" ]] && behind=0
  fi

  # stash 개수
  local stashed
  stashed=$(git stash list 2>/dev/null | wc -l | awk '{print $1}')

  # status 카운트(포슬린)
  local staged=0 conflicted=0 unstaged=0 wt_mod=0 untracked=0 staged_new=0 staged_del=0 staged_mod=0 unstaged_del=0
  local line X Y
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if [[ "${line[1,2]}" == "??" ]]; then
      untracked=$((untracked+1)); continue
    fi
    if [[ "${line[1,2]}" == "!!" ]]; then
      continue
    fi
    X="${line[1,1]}"; Y="${line[2,2]}"

    # 충돌
    if [[ "$X" == "U" || "$Y" == "U" ]]; then
      conflicted=$((conflicted+1))
    fi

    # 인덱스(좌측 X)
    case "$X" in
      A) staged=$((staged+1)); staged_new=$((staged_new+1)) ;;
      M) staged=$((staged+1)); staged_mod=$((staged_mod+1)) ;;
      D) staged=$((staged+1)); staged_del=$((staged_del+1)) ;;
      R|C|T) staged=$((staged+1)) ;; # 세부 유형은 요약
    esac

    # 워킹트리(우측 Y)
    case "$Y" in
      M|T) unstaged=$((unstaged+1)); wt_mod=$((wt_mod+1)) ;;
      D)   unstaged=$((unstaged+1)); unstaged_del=$((unstaged_del+1)) ;;
    esac
  done < <(git status --porcelain 2>/dev/null)

  # 라인 데이터(평문만) — tree, icon, label, vpre, num, vsuf, kind
  typeset -a T_TREE T_ICON T_LABEL T_VPRE T_NUM T_VSUF T_KIND
  local idx=0

  # Worktree 섹션
  idx=$((idx+1))
  T_TREE[$idx]="" ; T_ICON[$idx]="" ; T_LABEL[$idx]="Worktree" ; T_VPRE[$idx]="" ; T_NUM[$idx]="" ; T_VSUF[$idx]="" ; T_KIND[$idx]="section"

  # ├─ Unstaged(그룹)
  idx=$((idx+1))
  T_TREE[$idx]="├─ " ; T_ICON[$idx]="$I_GROUP_UNSTAGED" ; T_LABEL[$idx]="Unstaged"
  T_VPRE[$idx]="" ; T_NUM[$idx]="$unstaged" ; T_VSUF[$idx]=" files" ; T_KIND[$idx]="group_unstaged"

  # │  ├─ modified
  idx=$((idx+1))
  T_TREE[$idx]="│  ├─ " ; T_ICON[$idx]="$I_MODIFIED" ; T_LABEL[$idx]="modified"
  T_VPRE[$idx]="" ; T_NUM[$idx]="$wt_mod" ; T_VSUF[$idx]=" files" ; T_KIND[$idx]="wt_modified"

  # │  └─ deleted
  idx=$((idx+1))
  T_TREE[$idx]="│  └─ " ; T_ICON[$idx]="$I_DELETED" ; T_LABEL[$idx]="deleted"
  T_VPRE[$idx]="" ; T_NUM[$idx]="$unstaged_del" ; T_VSUF[$idx]=" files" ; T_KIND[$idx]="wt_deleted"

  # └─ Untracked
  idx=$((idx+1))
  T_TREE[$idx]="└─ " ; T_ICON[$idx]="$I_UNTRACKED" ; T_LABEL[$idx]="Untracked"
  T_VPRE[$idx]="" ; T_NUM[$idx]="$untracked" ; T_VSUF[$idx]=" files" ; T_KIND[$idx]="$([[ $untracked -gt 0 ]] && echo untracked || echo untracked)"

  # Index 섹션
  idx=$((idx+1))
  T_TREE[$idx]="" ; T_ICON[$idx]="" ; T_LABEL[$idx]="Index" ; T_VPRE[$idx]="" ; T_NUM[$idx]="" ; T_VSUF[$idx]="" ; T_KIND[$idx]="section"

  # ├─ Staged(그룹)
  idx=$((idx+1))
  T_TREE[$idx]="├─ " ; T_ICON[$idx]="$I_GROUP_STAGED" ; T_LABEL[$idx]="Staged"
  T_VPRE[$idx]="" ; T_NUM[$idx]="$staged" ; T_VSUF[$idx]=" files" ; T_KIND[$idx]="group_staged"

  # │  ├─ new
  idx=$((idx+1))
  T_TREE[$idx]="│  ├─ " ; T_ICON[$idx]="$I_NEW" ; T_LABEL[$idx]="new"
  T_VPRE[$idx]="" ; T_NUM[$idx]="$staged_new" ; T_VSUF[$idx]=" files" ; T_KIND[$idx]="staged_new"

  # │  ├─ deleted
  idx=$((idx+1))
  T_TREE[$idx]="│  ├─ " ; T_ICON[$idx]="$I_DELETED" ; T_LABEL[$idx]="deleted"
  T_VPRE[$idx]="" ; T_NUM[$idx]="$staged_del" ; T_VSUF[$idx]=" files" ; T_KIND[$idx]="staged_deleted"

  # │  └─ modified
  idx=$((idx+1))
  T_TREE[$idx]="│  └─ " ; T_ICON[$idx]="$I_MODIFIED" ; T_LABEL[$idx]="modified"
  T_VPRE[$idx]="" ; T_NUM[$idx]="$staged_mod" ; T_VSUF[$idx]=" files" ; T_KIND[$idx]="staged_modified"

  # └─ Conflicted
  idx=$((idx+1))
  T_TREE[$idx]="└─ " ; T_ICON[$idx]="$I_CONFLICT" ; T_LABEL[$idx]="Conflicted"
  T_VPRE[$idx]="" ; T_NUM[$idx]="$conflicted" ; T_VSUF[$idx]=" files" ; T_KIND[$idx]="conflicted"

  # Repo state 섹션
  idx=$((idx+1))
  T_TREE[$idx]="" ; T_ICON[$idx]="" ; T_LABEL[$idx]="Repo state" ; T_VPRE[$idx]="" ; T_NUM[$idx]="" ; T_VSUF[$idx]="" ; T_KIND[$idx]="section"

  # ├─ Stashed (Repo 단위 — 워킹트리 소속 아님)
  idx=$((idx+1))
  T_TREE[$idx]="├─ " ; T_ICON[$idx]="$I_STASH" ; T_LABEL[$idx]="Stashed"
  T_VPRE[$idx]="" ; T_NUM[$idx]="$stashed" ; T_VSUF[$idx]="" ; T_KIND[$idx]="stashed"

  # ├─ Ahead
  idx=$((idx+1))
  T_TREE[$idx]="├─ " ; T_ICON[$idx]="$I_AHEAD" ; T_LABEL[$idx]="Ahead"
  T_VPRE[$idx]="" ; T_NUM[$idx]="$ahead" ; T_VSUF[$idx]="" ; T_KIND[$idx]="ahead"

  # └─ Behind
  idx=$((idx+1))
  T_TREE[$idx]="└─ " ; T_ICON[$idx]="$I_BEHIND" ; T_LABEL[$idx]="Behind"
  T_VPRE[$idx]="" ; T_NUM[$idx]="$behind" ; T_VSUF[$idx]="" ; T_KIND[$idx]="behind"

  # 정렬: left = tree + icon(+두칸) + label
  local max_left=0 i icon_gap left_plain
  for i in {1..$idx}; do
    icon_gap=""
    [[ -n "${T_ICON[$i]}" ]] && icon_gap="  "
    left_plain="${T_TREE[$i]}${T_ICON[$i]}${icon_gap}${T_LABEL[$i]}"
    (( ${#left_plain} > max_left )) && max_left=${#left_plain}
  done

  # 아이콘 색 선택
  icon_color_for() {
    case "$1" in
      branch)          printf "%s" "$C_ICON_BRANCH" ;;
      group_unstaged)  printf "%s" "$C_ICON_GROUP_UNSTAGED" ;;
      wt_modified)     printf "%s" "$C_ICON_MODIFIED" ;;
      wt_deleted)      printf "%s" "$C_ICON_DELETED" ;;
      untracked)       printf "%s" "$C_ICON_UNTRACKED" ;;
      group_staged)    printf "%s" "$C_ICON_GROUP_STAGED" ;;
      staged_new)      printf "%s" "$C_ICON_NEW" ;;
      staged_deleted)  printf "%s" "$C_ICON_DELETED" ;;
      staged_modified) printf "%s" "$C_ICON_MODIFIED" ;;
      conflicted)      printf "%s" "$C_ICON_CONFLICT" ;;
      stashed)         printf "%s" "$C_ICON_STASH" ;;
      ahead)           printf "%s" "$C_ICON_AHEAD" ;;
      behind)          printf "%s" "$C_ICON_BEHIND" ;;
      section)         printf "%s" "" ;;
      *)               printf "%s" "" ;;
    esac
  }

  # 브랜치 라인(상단 별도)
  {
    # left 구성: 아이콘만 색, 숫자 없음
    local tree="" icon="$I_BRANCH" label="branch" icon_gap="  "
    local left_for_width="${tree}${icon}${icon_gap}${label}"
    local padspaces=$(( max_left - ${#left_for_width} ))
    (( padspaces < 0 )) && padspaces=0
    local sep=" : "
    # 아이콘만 색
    printf "%b%s%b%s%*s%s%s\n" \
      "$C_ICON_BRANCH" "$icon" "$RESET" \
      "${icon_gap}${label}" \
      "$padspaces" "" \
      "$sep" \
      "$branch"
  }

  # 구분선(색 없음)
  printf "%s\n" "----------------------------------------------------"

  # 라인 렌더(아이콘만 색, 숫자만 색)
  render_line() {
    local j="$1"
    local tree icon label kind vpre vnum vsuf
    tree="${T_TREE[$j]}"; icon="${T_ICON[$j]}"; label="${T_LABEL[$j]}"
    kind="${T_KIND[$j]}"; vpre="${T_VPRE[$j]}"; vnum="${T_NUM[$j]}"; vsuf="${T_VSUF[$j]}"

    local icon_gap=""
    [[ -n "$icon" ]] && icon_gap="  "

    local left_full="${tree}${icon}${icon_gap}${label}"
    local padspaces=$(( max_left - ${#left_full} ))
    (( padspaces < 0 )) && padspaces=0
    local sep=" : "

    local ICOLOR
    ICOLOR="$(icon_color_for "$kind")"

    # 섹션/제목(값 없음)
    if [[ -z "$vpre$vnum$vsuf" ]]; then
      if [[ -n "$icon" ]]; then
        printf "%s%b%s%b%s\n" \
          "$tree" \
          "$ICOLOR" "$icon" "$RESET" \
          "${icon_gap}${label}"
      else
        printf "%s%s\n" "$tree" "$label"
      fi
      return
    fi

    # 값 있는 줄: left + pad + " : " + vpre + (숫자만 색) + vsuf
    if [[ -n "$icon" ]]; then
      printf "%s%b%s%b%s%*s%s" \
        "$tree" \
        "$ICOLOR" "$icon" "$RESET" \
        "${icon_gap}${label}" \
        "$padspaces" "" \
        "$sep"
    else
      printf "%s%s%*s%s" \
        "$tree" \
        "$label" \
        "$padspaces" "" \
        "$sep"
    fi
    [[ -n "$vpre" ]] && printf "%s" "$vpre"
    if [[ -n "$vnum" ]]; then
      if (( vnum > 0 )); then
        # 1 이상 → 색상 적용
        printf "%b%s%b" "$C_NUM" "$vnum" "$RESET"
      else
        # 0일 땐 색상 없이 그냥 출력
        printf "%s" "$vnum"
      fi
    fi
    [[ -n "$vsuf" ]] && printf "%s" "$vsuf"
    printf "\n"
  }

  # 나머지 라인 출력
  for i in {1..$idx}; do
    # 위에서 Worktree 제목부터 구성했으므로, 브랜치와 구분선 이후 전체를 그대로 렌더
    render_line $i
  done
}

