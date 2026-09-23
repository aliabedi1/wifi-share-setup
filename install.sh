#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
  echo 'Run this installer with sudo.' >&2
  exit 1
fi

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if ! command -v hostapd >/dev/null || ! command -v dnsmasq >/dev/null; then
  apt-get update
  apt-get install -y hostapd dnsmasq-base
fi

install -d -m 700 /etc/wifi-share
if [[ ! -s /etc/wifi-share/password ]]; then
  umask 077
  openssl rand -hex 12 > /etc/wifi-share/password
  echo 'Generated hotspot password:'
  cat /etc/wifi-share/password
fi
install -d -m 755 /usr/local/libexec
install -m 755 "$repo_dir/bin/wifi-share" /usr/local/bin/wifi-share
install -m 755 "$repo_dir/libexec/wifi-share-root" /usr/local/libexec/wifi-share-root
install -m 644 "$repo_dir/systemd/wifi-share-ap.service" /etc/systemd/system/wifi-share-ap.service
install -m 644 "$repo_dir/systemd/wifi-share-dhcp.service" /etc/systemd/system/wifi-share-dhcp.service
systemctl daemon-reload

if command -v ufw >/dev/null; then
  ufw allow in on ap0 to any port 67 proto udp
  ufw allow in on ap0 to any port 53 proto udp
  ufw allow in on ap0 to any port 53 proto tcp
  ufw route allow in on ap0 out on wlp2s0
fi

/usr/local/libexec/wifi-share-root on
