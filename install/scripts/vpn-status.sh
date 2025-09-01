#!/usr/bin/env bash
set -euo pipefail

# VPN 인터페이스 패턴 (ppp0, ppp1, ppp2 등 모두 커버; 필요 시 확장)
VPN_PATTERN='^(ppp|tun|tap|wg|tailscale)[0-9]*$'

# 디버그 함수: DEBUG=1 일 때만 출력
debug_echo() {
  if [[ "${DEBUG:-0}" == "1" ]]; then
    echo "DEBUG: $1" >&2
  fi
}

# 모든 인터페이스 정보를 JSON으로 한 번 가져옴 (ip -j addr show)
json_data=$(ip -j addr show 2>/dev/null)

# 모든 인터페이스 이름 추출 (jq 필요; 없으면 awk 대안 사용)
all_ifaces=$(echo "$json_data" | jq -r '.[].ifname')

has_vpn=false
for ifc in $all_ifaces; do
  # 패턴 매칭으로 VPN 후보 필터링
  if [[ "$ifc" =~ $VPN_PATTERN ]]; then
    debug_echo "Checking VPN candidate: $ifc"

    # jq로 해당 인터페이스의 데이터 추출
    iface_json=$(echo "$json_data" | jq --arg ifc "$ifc" '.[] | select(.ifname == $ifc)')

    if [[ -n "$iface_json" ]]; then
      # operstate 추출 (UP 또는 UNKNOWN)
      oper_state=$(echo "$iface_json" | jq -r '.operstate')
      debug_echo "  - Operstate: $oper_state"

      # flags에서 UP/LOWER_UP 확인
      flags=$(echo "$iface_json" | jq -r '.flags[]' | tr '\n' ' ')
      debug_echo "  - Flags: $flags"

      # addr_info에서 inet IP 유무 확인
      has_ip=$(echo "$iface_json" | jq '.addr_info[] | select(.family == "inet")' | grep -q '.' && echo "Yes" || echo "No")
      debug_echo "  - Has IP: $has_ip"

      # 라우트 엔트리 유무 확인
      has_routes=$(ip route show dev "$ifc" 2>/dev/null | grep -q '.' && echo "Yes" || echo "No")
      debug_echo "  - Has routes: $has_routes"

      # 조건: operstate UP/UNKNOWN, flags에 UP 포함, IP 있음, routes 있음
      if [[ "$oper_state" =~ ^(UP|UNKNOWN)$ ]] && [[ "$flags" == *"UP"* ]] && [[ "$has_ip" == "Yes" ]] && [[ "$has_routes" == "Yes" ]]; then
        debug_echo "  - All checks passed for $ifc"
        has_vpn=true
        vpn_iface="$ifc"
        break # 첫 번째 맞는 인터페이스에서 멈춤
      else
        debug_echo "  - Checks failed for $ifc"
      fi
    fi
  fi
done

if $has_vpn; then
  debug_echo "VPN detected via $vpn_iface"

  # 선택적 ping 체크 (USE_PING=1 로 활성화)
  if [[ "${USE_PING:-0}" == "1" ]]; then
    if ping -q -c1 -W1 -I "$vpn_iface" 8.8.8.8 >/dev/null 2>&1; then
      debug_echo "Ping check: Success"
    else
      debug_echo "Ping check: Failed"
      echo ""
      exit 0
    fi
  fi

  echo "🔒 VPN"
else
  debug_echo "No VPN detected"
  echo ""
fi
