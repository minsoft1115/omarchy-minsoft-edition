#!/bin/bash

# awk를 사용하여 /proc/meminfo 파일에서 직접 메모리 정보 추출 및 계산
awk '
/MemTotal/ {total=$2}
/MemAvailable/ {available=$2}
END {
    # 사용량 계산 (전체 - 사용 가능)
    used = total - available

    # 0으로 나누기 오류 방지
    if (total == 0) {
        percent = 0
        filled_blocks = 0
    } else {
        # 백분율 및 게이지 바 블록 수 계산 (반올림)
        percent = sprintf("%.0f", (used/total)*100)
        filled_blocks = sprintf("%.0f", (used*10)/total)
    }

    # 게이지 바 문자열 생성
    bar = ""
    for (i=0; i<filled_blocks; i++) bar = bar "■"
    for (i=0; i<10-filled_blocks; i++) bar = bar "□"

    # KB 단위를 GiB 단위로 변환
    used_gib = sprintf("%.2f GiB", used/1024/1024)
    total_gib = sprintf("%.2f GiB", total/1024/1024)

    # 최종 결과 출력
    printf "[%s] %d%% (%s / %s)\n", bar, percent, used_gib, total_gib
}
' /proc/meminfo


