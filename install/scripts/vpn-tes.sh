#!/usr/bin/env bash
set -euo pipefail

# 1) 정적 후보(확실히 쓰는 것)
STATIC_IFACES=("ppp0" "tun0" "wg0" "tailscale0")

# 2) 패턴 후보(여러 VPN이 흔히 쓰는 접두)
PATTERNS=("tun" "tap" "wg" "ppp" "zt" "vpn")

# 현재 활성 인터페이스 목록
mapfile -t LINKS < <(ip -o link show | awk -F': ' '{print $2}' | sed 's/@.*//')

has_vpn_iface=false
vpn_iface=""

# 정적 후보 우선 확인
for ifc in "${STATIC_IFACES[@]}"; do
  if ip link show "$ifc" >/dev/null 2>&1; then
    has_vpn_iface=true
    vpn_iface="$ifc"
    break
  fi
done

# 패턴 매칭(정적 후보에서 못 찾았을 때)
if ! $has_vpn_iface; then
  for name in "${LINKS[@]}"; do
    for p in "${PATTERNS[@]}"; do
      if [[ "$name" =~ ^${p}[0-9A-Fa-f]*$ ]] || [[ "$name" == "tailscale0" ]]; then
        # 인터페이스가 up 상태면 채택(원하면 상태 체크 생략 가능)
        if ip addr show "$name" | grep -q "state UP"; then
          has_vpn_iface=true
          vpn_iface="$name"
          break 2
        fi
      fi
    done
  done
fi

# 기본 경로(dev) 추출
default_if=$(ip route show default 2>/dev/null | awk '/default/ {for(i=1;i<=NF;i++) if ($i=="dev") print $(i+1)}' | head -n1)

# 프로세스 신호(환경에 맞게 추가/수정 가능)
has_vpn_proc=false
if pgrep -x openvpn >/dev/null 2>&1 || pgrep -x wg-quick >/dev/null 2>&1 || pgrep -x tailscaled >/dev/null 2>&1 || pgrep -x zerotier-one >/dev/null 2>&1; then
  has_vpn_proc=true
fi

# 종합 판정: 인터페이스가 있고, (기본경로가 그 iface이거나 프로세스가 살아있으면) VPN
if $has_vpn_iface && { [[ "$default_if" == "${vpn_iface:-}" ]] || $has_vpn_proc; }; then
  echo "🔒 VPN"
else
  echo ""
fi
