#!/bin/bash

SSID="HOTSPOT"
PASSWORD="12345678"

echo "[HOTSPOT] Starting hotspot..."

# Stop any existing hotspot
nmcli connection down Hotspot 2>/dev/null

# Create hotspot
nmcli device wifi hotspot ifname wlan0 ssid "$SSID" password "$PASSWORD"

echo "[HOTSPOT] Hotspot started: $SSID"
