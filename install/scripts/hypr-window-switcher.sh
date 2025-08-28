#!/usr/bin/env bash
set -euo pipefail

# =====
# Config
# =====
DEFAULT_GLYPH=' '
LOCKFILE="/tmp/hypr-window-switcher.lock"
DEBUG="${DEBUG:-0}" # DEBUG=1 ./hypr-window-switcher.sh

# =====
# Debug helpers
# =====
log() { printf '[DBG] %s\n' "$*" >&2; }
dump_block() { # 이름, 내용, 프리뷰 줄 수
  local name="$1" data="$2" n="${3:-20}"
  local lines
  lines="$(printf '%s\n' "$data" | wc -l | tr -d ' ')"
  log "----- $name (lines=$lines, preview=$n) -----"
  printf '%s\n' "$data" | sed -n "1,${n}p" | sed 's/\t/    [TAB]    /g' >&2
  if [ "$lines" -gt "$n" ]; then log "----- (truncated; total $lines lines) -----"; fi
}

# =====
# Single instance lock
# =====
exec 9>"$LOCKFILE" || exit 0
flock -n 9 || exit 0
trap 'rm -f "$LOCKFILE"' EXIT INT TERM

# =====
# 1) Data collection
# =====
get_clients_json() {
  local json
  if ! json="$(hyprctl -j clients 2>/dev/null)"; then
    return 1
  fi
  if ! jq -e 'type=="array" and length>0' >/dev/null <<<"$json"; then
    return 1
  fi
  printf '%s' "$json"
}

# =====
# 2) jq: JSON -> TSV(필드만)
# 출력: ws_id<TAB>class<TAB>title<TAB>addr
# =====
extract_tsv_fields_from_json() {
  local json="$1"
  jq -r '
    .[] | [
      (.workspace.id // 0),
      (.class // ""),
      (.title // ""),
      (.address | tostring // "")
    ] | @tsv
  ' <<<"$json"
}

# =====
# 3) 정렬(선택): ws, class, title 순
# =====
sort_menu_rows() {
  local raw_tsv="$1"
  sort -t $'\t' -k1,1n -k2,2 -k3,3 <<<"$raw_tsv"
}

# =====
# 4) 아이콘 조회: JSON 배열 [{key,value}]에서 클래스 소문자 정확 일치
# - 마지막 규칙 우선: 뒤에서 앞으로 순회
# =====
find_icon_from_json_array() {
  local json_arr_str="$1"
  local class_name="$2"
  local cls_l
  cls_l="${class_name,,}"
  # 뒤에서 앞으로 순회해 첫 매치 반환
  while IFS=$'\t' read -r key_l glyph; do
    if [[ "$cls_l" == "$key_l" ]]; then
      echo "$glyph"
      return 0
    fi
  done < <(printf '%s' "$json_arr_str" | jq -r '
    to_entries | reverse | map(.value) |
    .[] | [(.key|ascii_downcase), .value] | @tsv
  ')
  echo ""
}

# =====
# 5) Bash로 메뉴 TSV 구성
# 입력: ws<TAB>class<TAB>title<TAB>addr
# 출력: ws_num<TAB>label<TAB>addr
# =====
build_menu_tsv_bash() {
  local sorted_tsv="$1"
  local default_glyph="$2"
  local json_arr_str="${HYPR_CLASS_ICON_MAP_JSON:-[]}"

  # 워크스페이스별 카운터
  declare -A count
  local ws cls ttl addr gl ws_num ws_label

  while IFS=$'\t' read -r ws cls ttl addr; do
    # 한 줄 정규화
    cls="${cls//$'\r'/ }"
    cls="${cls//$'\n'/ }"
    cls="${cls//$'\t'/ }"
    ttl="${ttl//$'\r'/ }"
    ttl="${ttl//$'\n'/ }"
    ttl="${ttl//$'\t'/ }"

    # 워크스페이스 카운터 증가
    if [[ -z "${count[$ws]:-}" ]]; then count[$ws]=0; fi
    count[$ws]=$((count[$ws] + 1))

    ws_num="W${ws}#${count[$ws]}"
    if [[ ${count[$ws]} -eq 1 ]]; then
      ws_label="Workspace ${ws}"
    else
      ws_label="           "
    fi

    # 아이콘 조회(클래스 소문자화 후 JSON 배열에서 찾기)
    gl="$(find_icon_from_json_array "$json_arr_str" "$cls")"
    [[ -z "$gl" ]] && gl="$default_glyph"

    # 라벨 합성
    printf '%s\t%s (%s)  %s  "%s"  (%s)\t%s\n' \
      "$ws_num" "$ws_label" "$ws_num" "$gl" "$ttl" "$cls" "$addr"
  done <<<"$sorted_tsv"
}

# =====
# 6) walker용 라벨만 추출
# =====
extract_labels() {
  local menu_tsv="$1"
  cut -f2 <<<"$menu_tsv"
}

# =====
# 7) 메뉴 표시
# =====
show_menu() {
  local labels="$1"
  walker --dmenu --theme dmenu_250 -w 1400 -p "Select Window…" <<<"$labels" || return 1
}

# =====
# 8) (Wn#m)로 ws_num 추출 -> addr 역조회
# =====
extract_wsnum_from_label() {
  local label="$1"
  local prefix wsnum

  # 1) 첫 번째 ')' 위치까지 접두부만 자르기
  #    접두부 예: "Workspace 2 (W2#1)" 또는 "           (W2#2)"
  prefix="${label%%)*})" # 잘못된 시도 방지용 주석

  # 위 한 줄은 오타. 올바른 구현은 아래 2줄처럼 한다.

  # - 먼저 첫 ')'까지 자르기: parameter expansion 사용
  #   "${var%%)*}"는 ')' 포함 ')*' 패턴을 뒤에서부터 제거하므로 적합하지 않다.
  #   대신 sed로 첫 ')'까지를 추출하는게 가장 명확하다.
  prefix="$(printf '%s' "$label" | sed 's/).*$/)/')"

  # 2) 접두부에서 마지막 '(' 이후 텍스트만 추출 → "Wn#m)" 형태
  #    이렇게 하면 앞쪽의 "Workspace 2 "나 공백 패딩은 자동으로 제거된다.
  wsnum="$(printf '%s' "$prefix" | awk -F'(' '{print $NF}' | tr -d ')')"

  # 3) 최소 검증: 형태가 W<digits>#<digits> 인지 확인
  case "$wsnum" in
  W*[0-9]#[0-9]*)
    printf '%s' "$wsnum"
    ;;
  *)
    # 실패 시 빈 문자열
    printf ''
    ;;
  esac
}

lookup_addr_by_wsnum() {
  local menu_tsv="$1"
  local wsnum="$2"
  [[ -z "$wsnum" ]] && return 0
  awk -F'\t' -v k="$wsnum" '$1==k{print $3; exit}' <<<"$menu_tsv"
}

# =====
# 9) 포커스 시퀀스
# =====
focus_window_sequence() {
  local addr="$1"
  [[ -z "$addr" ]] && return 0

  hyprctl dispatch focuswindow "address:$addr" >/dev/null 2>&1 || true
}

# =====
# Main
# =====
main() {
  local clients_json raw_tsv sorted_tsv menu_tsv labels choice wsnum addr

  # 참고: 아래 캐시 로더는 현재 아이콘 매핑에 직접 사용하지 않음(디버그용).
  # HYPR_CLASS_ICON_MAP_JSON(JSON 배열)을 직접 사용한다.
  if [[ -n "${HYPR_CLASS_ICON_MAP_JSON:-}" && "$DEBUG" -eq 1 ]]; then
    # 사람이 보기 좋게 key TAB glyph로 미리보기
    local preview_lines
    preview_lines="$(printf '%s' "$HYPR_CLASS_ICON_MAP_JSON" | jq -r '.[] | [.key, .value] | @tsv' | sed 's/\t/    [TAB]    /g' | sed -n '1,10p')"
    dump_block "icon_map_json (preview key[TAB]glyph)" "$preview_lines" 10
  fi

  clients_json="$(get_clients_json)" || exit 0

  if [[ "$DEBUG" -eq 1 ]]; then
    log "clients_json bytes: $(printf '%s' "$clients_json" | wc -c | tr -d ' ')"
    printf '%s\n' "$clients_json" | jq '.[0] | {ws: .workspace.id, title: .title, class: .class, address: .address}' 2>/dev/null >&2 || true
  fi

  raw_tsv="$(extract_tsv_fields_from_json "$clients_json")" || exit 0
  [[ "$DEBUG" -eq 1 ]] && dump_block "raw_tsv (ws\tclass\ttitle\taddr)" "$raw_tsv" 20

  sorted_tsv="$(sort_menu_rows "$raw_tsv")"
  [[ "$DEBUG" -eq 1 ]] && dump_block "sorted_tsv" "$sorted_tsv" 20

  menu_tsv="$(build_menu_tsv_bash "$sorted_tsv" "$DEFAULT_GLYPH")" || exit 0
  [[ "$DEBUG" -eq 1 ]] && dump_block "menu_tsv (ws_num\tlabel\taddr)" "$menu_tsv" 40

  labels="$(extract_labels "$menu_tsv")"
  [[ "$DEBUG" -eq 1 ]] && dump_block "labels (for walker)" "$labels" 40

  choice="$(show_menu "$labels")" || exit 0
  [[ -z "$choice" || "$choice" == "CNCLD" ]] && exit 0
  [[ "$DEBUG" -eq 1 ]] && log "choice: $choice"

  wsnum="$(extract_wsnum_from_label "$choice")"
  [[ "$DEBUG" -eq 1 ]] && log "parsed wsnum: $wsnum"

  addr="$(lookup_addr_by_wsnum "$menu_tsv" "$wsnum")"
  [[ "$DEBUG" -eq 1 ]] && log "resolved addr: $addr"

  printf '[INFO] focusing: "%s" -> addr=%s\n' "$choice" "$addr"
  focus_window_sequence "$addr"
}

main "$@"
