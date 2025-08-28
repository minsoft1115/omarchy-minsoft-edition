#!/usr/bin/env zsh

# --- 1. Git 저장소인지 우선 확인 ---
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "This is not a Git repository." >&2
  exit 1
fi

# --- 2. gitstatus 플러그인 경로 설정 및 파일 존재 여부 확인 ---
GITSTATUS_PLUGIN_FILE="${HOME}/gitstatus/gitstatus.plugin.zsh"

if [[ ! -f "$GITSTATUS_PLUGIN_FILE" ]]; then
  echo "Error: gitstatus plugin not found at '$GITSTATUS_PLUGIN_FILE'." >&2
  echo "Please install it via: git clone --depth=1 https://github.com/romkatv/gitstatus.git ~/gitstatus" >&2
  exit 1
fi

# --- 3. 파일 권한 및 무결성 검사 (새로 추가된 핵심 로직) ---
# 파일에 읽기/실행 권한이 없으면 source가 실패하므로 권한을 부여합니다.
if [[ ! -r "$GITSTATUS_PLUGIN_FILE" || ! -x "$GITSTATUS_PLUGIN_FILE" ]]; then
  echo "Info: Adding read/execute permissions to gitstatus plugin file..."
  chmod +rx "$GITSTATUS_PLUGIN_FILE"
fi

# 파일이 온전한지 간단히 확인합니다. 'gitstatus_start' 문자열이 없으면 비정상입니다.
if ! grep -q "gitstatus_start" "$GITSTATUS_PLUGIN_FILE"; then
    echo "Error: The file '$GITSTATUS_PLUGIN_FILE' seems corrupted or incomplete." >&2
    echo "Please try re-installing gitstatus:" >&2
    echo "  rm -rf ~/gitstatus" >&2
    echo "  git clone --depth=1 https://github.com/romkatv/gitstatus.git ~/gitstatus" >&2
    exit 1
fi

# --- 4. 플러그인 로드 및 검증 ---
source "$GITSTATUS_PLUGIN_FILE"

if ! typeset -f gitstatus_query >/dev/null 2>&1; then
  echo "Error: Failed to load gitstatus functions even after checking permissions." >&2
  echo "There might be an issue with your zsh environment. Please try running 'source ~/gitstatus/gitstatus.plugin.zsh' directly in your terminal." >&2
  exit 1
fi

# --- 5. 데몬 실행 및 Git 상태 요약 (이전과 동일) ---
readonly DAEMON_ID="GIT_SUMMARY_DAEMON"

if ! gitstatus_query "$DAEMON_ID"; then
  gitstatus_start "$DAEMON_ID"
  if ! gitstatus_query "$DAEMON_ID"; then
    echo "Error: Failed to communicate with the gitstatusd daemon." >&2
    exit 1
  fi
fi

local branch ahead behind staged conflicted unstaged untracked stashed
branch="${VCS_STATUS_LOCAL_BRANCH:-@${VCS_STATUS_COMMIT:0:7}}"
ahead=$VCS_STATUS_AHEAD
behind=$VCS_STATUS_BEHIND
staged=$VCS_STATUS_NUM_STAGED
conflicted=$VCS_STATUS_NUM_CONFLICTED
unstaged=$VCS_STATUS_NUM_UNSTAGED
untracked=$VCS_STATUS_NUM_UNTRACKED
stashed=$VCS_STATUS_NUM_STASHED

local output="\e[1;32m$branch\e[0m"
local status_summary

(( ahead > 0 ))      && status_summary+=" ↑$ahead"
(( behind > 0 ))     && status_summary+=" ↓$behind"
(( staged > 0 ))     && status_summary+=" +$staged"
(( conflicted > 0 )) && status_summary+=" ~$conflicted"
(( unstaged > 0 ))   && status_summary+=" !$unstaged"
(( untracked > 0 ))  && status_summary+=" ?$untracked"
(( stashed > 0 ))    && status_summary+=" *$stashed"

if [[ -n "$status_summary" ]]; then
  output+=" \e[2;90m[${status_summary# }]\e[0m"
fi

printf "%s\n" "$output"

