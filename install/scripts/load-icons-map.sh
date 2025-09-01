#!/usr/bin/env bash
set -euo pipefail

# 설정
ICONS_FILE_DEFAULT="$HOME/.config/hypr/icons.map"

require_deps() {
  command -v jq >/dev/null 2>&1 || {
    echo "Error: jq not found." >&2
    exit 1
  }
}

# 1) 파일 줄단위 필터: 주석/빈줄 제거 + trim
filter_lines() {
  # $1: FILE
  local file="${1:?}"
  [[ -f "$file" ]] || {
    echo "Error: file not found: $file" >&2
    exit 1
  }

  while IFS= read -r line || [[ -n "${line:-}" ]]; do
    # 좌우 공백 제거
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    # 빈줄/주석 스킵
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^# ]] && continue
    printf '%s\n' "$line"
  done <"$file"
}

# 2) 라인을 key:value로 분리 → key/value 좌우+내부 공백 제거 → key<TAB>value 출력
to_tab_pairs() {
  local line key val
  while IFS= read -r line; do
    [[ "$line" != *:* ]] && continue
    key="${line%%:*}"
    val="${line#*:}"

    # 좌우 공백 제거
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    val="${val#"${val%%[![:space:]]*}"}"
    val="${val%"${val##*[![:space:]]}"}"

    # 내부 공백 제거(공백 없음 강제)
    key="${key//[[:space:]]/}"
    val="${val//[[:space:]]/}"

    [[ -z "$key" || -z "$val" ]] && continue
    printf '%s\t%s\n' "$key" "$val"
  done
}

# 3) 탭 쌍을 [{key:"...", value:"..."}] JSON 배열(객체)로 변환
pairs_to_json_array_obj() {
  jq -R -s '
    split("\n")
    | map(select(length>0))
    | map(split("\t"))
    | map({key: .[0], value: .[1]})
  '
}

# 4) JSON 배열(객체)을 “한 줄 JSON 문자열”로 직렬화
json_array_obj_to_oneline_string() {
  jq -c '.'
}

# 5) 한 줄 JSON 문자열에서 특정 key의 value만 조회
query_value_from_oneline_json_array() {
  # $1: JSON_ARRAY_STR (string)
  # $2: KEY
  local json_str="${1:?}"
  local key="${2:?}"
  echo "$json_str" |
    jq -r --arg k "$key" '
      fromjson
      | [ .[] | select(.key == $k) | .value ]
      | last // empty
    '
}

find_icon_bash() {
  local json_str="$1"
  local target_key="$2"
  local key val

  # jq는 파싱과 안전한 탭 구분 출력만 담당, 선택/비교는 bash에서 수행
  # .[]로 배열 순회 → "\t"로 key<TAB>value 출력
  while IFS=$'\t' read -r key val; do
    # 정확 일치 비교
    if [[ "$key" == "$target_key" ]]; then
      printf '%s\n' "$val"
      return 0
    fi
  done < <(printf '%s' "$json_str" | jq -r '.[] | [.key, .value] | @tsv')

  # 못 찾으면 빈 출력(또는 에러 코드 반환 원하면 주석 해제)
  # return 1
}

# 새 함수: key를 class<( … )> 에서 … 로 치환
normalize_key_class_pattern() {
  # stdin: "key<TAB>value" 줄들
  # stdout: "normalized_key<TAB>value"
  awk -F'\t' '
    {
      key=$1; val=$2
      # key가 class<( ... )> 형태인지 검사
      if (key ~ /^class<\(.*\)>$/) {
        # 내부 패턴만 추출: class<( ... )> 에서 ... 부분
        # sub: 앞부분 "class<(" 제거
        sub(/^class<\(/, "", key)
        # sub: 뒷부분 ")>" 제거
        sub(/\)>$/, "", key)
      }
      printf("%s\t%s\n", key, val)
    }
  '
}

# JSON 배열을 받아 key를 '|'로 분해해 value를 복제하여 평탄화
expand_keys_by_pipe() {
  jq '
    # 각 객체에 대해 key를 split("|") 해서 각 토큰마다 새 객체로 변환
    map(
      . as $o
      | ($o.key | split("|"))
      | map({key: ., value: $o.value})
    )
    | flatten
  '
}

normalize_case_classes_to_lower() {
  jq '
    def collapse_pair:
      # 26자 모든 대/소문자 쌍을 소문자 단일 문자로 치환
      gsub("\\[Aa\\]"; "a") | gsub("\\[Bb\\]"; "b") | gsub("\\[Cc\\]"; "c") | gsub("\\[Dd\\]"; "d") |
      gsub("\\[Ee\\]"; "e") | gsub("\\[Ff\\]"; "f") | gsub("\\[Gg\\]"; "g") | gsub("\\[Hh\\]"; "h") |
      gsub("\\[Ii\\]"; "i") | gsub("\\[Jj\\]"; "j") | gsub("\\[Kk\\]"; "k") | gsub("\\[Ll\\]"; "l") |
      gsub("\\[Mm\\]"; "m") | gsub("\\[Nn\\]"; "n") | gsub("\\[Oo\\]"; "o") | gsub("\\[Pp\\]"; "p") |
      gsub("\\[Qq\\]"; "q") | gsub("\\[Rr\\]"; "r") | gsub("\\[Ss\\]"; "s") | gsub("\\[Tt\\]"; "t") |
      gsub("\\[Uu\\]"; "u") | gsub("\\[Vv\\]"; "v") | gsub("\\[Ww\\]"; "w") | gsub("\\[Xx\\]"; "x") |
      gsub("\\[Yy\\]"; "y") | gsub("\\[Zz\\]"; "z");

    map(.key = (.key | collapse_pair))
  '
}

# -------- 메인 --------
require_deps

ICONS_FILE="${1:-$ICONS_FILE_DEFAULT}"

# A) JSON 한 줄 문자열 변수 만들기
HYPR_CLASS_ICON_MAP_JSON="$(
  filter_lines "$ICONS_FILE" |
    to_tab_pairs |
    normalize_key_class_pattern |
    pairs_to_json_array_obj |
    expand_keys_by_pipe |
    jq 'map(.key = (.key | ascii_downcase))' | # ← 여기서 키를 무조건 소문자
    #normalize_case_classes_to_lower |
    json_array_obj_to_oneline_string
)"

echo $HYPR_CLASS_ICON_MAP_JSON
export HYPR_CLASS_ICON_MAP_JSON="$HYPR_CLASS_ICON_MAP_JSON"

# 배열 개수(count) 로그 출력
count="$(printf '%s' "$HYPR_CLASS_ICON_MAP_JSON" | jq '. | length')"
echo "[INFO] HYPR_CLASS_ICON_MAP_JSON entries: $count"
