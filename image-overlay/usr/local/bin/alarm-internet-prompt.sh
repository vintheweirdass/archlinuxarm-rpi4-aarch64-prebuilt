#!/usr/bin/env bash
set -euo pipefail

log() { echo "[ALArm Internet Prompt]: $*"; }

STATE_DIR="/var/lib/alarm-rpi-postinstall"
mkdir -p "$STATE_DIR"

# Find the default interface used for outbound traffic
main_iface=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $5; exit}')
if [[ -z "$main_iface" ]]; then
  log "No default route found – assuming no network."
  exit 0
fi

# Check if default interface is up
operstate=$(< /sys/class/net/"$main_iface"/operstate 2>/dev/null || echo "down")
if [[ "$operstate" != "up" ]]; then
  log "Interface $main_iface is not up (state: $operstate); no network active."
  exit 0
fi

# Detect interface type (Wi‑Fi vs Ethernet)
if [[ -d /sys/class/net/"$main_iface"/wireless ]] || [[ -L /sys/class/net/"$main_iface"/phy80211 ]]; then
  iface_type="wifi"
else
  iface_type="ethernet"
fi

log "Default route via: $main_iface ($iface_type)"

# Check connectivity via TCP
if nc -vz example.com 80 > /dev/null 2>&1; then
  log "Internet reachable"
  echo "$(date): success" > "$STATE_DIR/success"
  NETWORK_OK=true
else
  log "No outbound connectivity detected"
  NETWORK_OK=false
fi

# If interface is Wi‑Fi and there’s no net, prompt
if [[ "$iface_type" == "wifi" ]] && ! $NETWORK_OK; then
  log "Wi‑Fi interface present and active, but no internet."
  if /usr/local/bin/alarm-rpi-prompt-wifi.sh && nc -vz example.com 80 > /dev/null 2>&1; then
    log "Internet restored after Wi‑Fi prompt"
  else
    log "User declined Wi‑Fi configuration or it failed"
    exit 1
  fi
fi

# If interface is Ethernet and there's no network—but Wi‑Fi exists unused
if [[ "$iface_type" == "ethernet" ]] && ! $NETWORK_OK; then
  # Check if any Wi‑Fi hardware exists but not configured
  if command -v lshw >/dev/null 2>&1 && lshw -C network 2>/dev/null | grep -iq wireless || \
     lsusb | grep -iq wireless; then
    log "Wi‑Fi hardware detected but not in use on default interface."
    log "Prompting user: Configure Wi‑Fi instead of Ethernet?"
    if /usr/local/bin/alarm-rpi-prompt-wifi.sh && nc -vz example.com 80 > /dev/null 2>&1; then
      log "Switched to Wi‑Fi and internet now available"
      echo "$(date): success" > "$STATE_DIR/success"
      NETWORK_OK=true
    else
      log "User declined or failed to configure Wi‑Fi; continuing with Ethernet"
    fi
  else
    log "Ethernet used; no other Wi‑Fi hardware present."
  fi
fi

# Run package operations if network is available
if $NETWORK_OK; then
  log "Network live – running system setup"
  exit 0
else
  log "No connectivity available after attempts – exiting"
  exit 1
fi
