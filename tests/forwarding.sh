#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
  echo 'Run this test with sudo while the hotspot is on.' >&2
  exit 1
fi
if ! systemctl is-active --quiet wifi-share-ap.service; then
  echo 'Turn on the hotspot first.' >&2
  exit 1
fi

namespace="wifi-share-test-$$"
host_if="hst$$"
client_if="clt$$"
cleanup() {
  ip route del 10.42.7.253/32 dev "$host_if" 2>/dev/null || true
  ip link del "$host_if" 2>/dev/null || true
  ip netns del "$namespace" 2>/dev/null || true
}
trap cleanup EXIT

ip netns add "$namespace"
ip link add "$host_if" type veth peer name "$client_if"
ip link set "$client_if" netns "$namespace"
ip addr add 10.42.7.254/32 dev "$host_if"
ip link set "$host_if" up
ip -n "$namespace" addr add 10.42.7.253/32 dev "$client_if"
ip -n "$namespace" link set lo up
ip -n "$namespace" link set "$client_if" up
ip -n "$namespace" route add default via 10.42.7.254 dev "$client_if" onlink
ip route add 10.42.7.253/32 dev "$host_if"

ip netns exec "$namespace" ping -c 3 -W 2 1.1.1.1
