#!/bin/bash

# --- CONFIGURATION ---
BUTTON_DEVICE=$(awk '/Phys=adc-keys\/input0/{flag=1} flag && /Handlers=/{for(i=1;i<=NF;i++) if($i ~ /^event[0-9]+$/) {print "/dev/input/"$i; exit}}' /proc/bus/input/devices)
BUTTON_CODE="115"                  # KEY_VOLUMEUP
LED_TRIGGER_PATH="/sys/class/leds/status-led/trigger"
LED_BRIGHTNESS_PATH="/sys/class/leds/status-led/brightness"
# ---------------------

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo)."
  exit 1
fi

# Track the state (0 = Off, 1 = On)
HOTSPOT_ACTIVE=0
BLINK_PID=""

# 1. Save the original system LED trigger at boot
#ORIG_TRIGGER=$(cat "$LED_TRIGGER_PATH" | grep -o '\[[^]]*\]' | tr -d '[]')

ORIG_TRIGGER=$(grep -o '\[[^]]*\]' "$LED_TRIGGER_PATH" | tr -d '[]')

# If no bracketed trigger is found, fallback to the raw text content
if [ -z "$ORIG_TRIGGER" ]; then
    #ORIG_TRIGGER=$(cat "$LED_TRIGGER_PATH" | awk '{print $1}')

    ORIG_TRIGGER=$(awk '{print $1}' "$LED_TRIGGER_PATH")
fi
echo "Detected normal LED operation trigger: $ORIG_TRIGGER"

# Background function to blink the LED every 500ms
led_blinker() {
    echo "none" > "$LED_TRIGGER_PATH"
    while true; do
        echo "1" > "$LED_BRIGHTNESS_PATH"
        sleep 0.5
        echo "0" > "$LED_BRIGHTNESS_PATH"
        sleep 0.5
    done
}

toggle_hotspot() {
    if [ "$HOTSPOT_ACTIVE" -eq 0 ]; then
        echo "Turning ON hotspot..."
        HOTSPOT_ACTIVE=1
        
        # Start the background LED blinker and save its process ID (PID)
        led_blinker &
        BLINK_PID=$!
        
        # Turn on the NetworkManager hotspot connection
        nmcli connection up id "Hotspot"
    else
        echo "Turning OFF hotspot..."
        HOTSPOT_ACTIVE=0
        
        # Stop the background LED blinking process
        if [ -n "$BLINK_PID" ]; then
            kill "$BLINK_PID" 2>/dev/null
            wait "$BLINK_PID" 2>/dev/null
        fi
        
        # Turn off the NetworkManager hotspot connection
        nmcli connection down id "Hotspot"
        
        # Restore the LED back to its original system state
        echo "Restoring LED to normal operation ($ORIG_TRIGGER)..."
        echo "$ORIG_TRIGGER" > "$LED_TRIGGER_PATH"
    fi
}

echo "Monitoring button on $BUTTON_DEVICE..."

# Use stdbuf to prevent buffering issues and listen for button down event (value 1)
# Looking for lines matching: "code 115 (KEY_VOLUMEUP), value 1"
#evtest "$BUTTON_DEVICE" | stdbuf -oL grep --line-buffered -E "code $BUTTON_CODE .* value 1" | while read -r line; do
evtest "$BUTTON_DEVICE" | stdbuf -oL grep --line-buffered -E "code $BUTTON_CODE .* value 1" | while read -r _; do

toggle_hotspot
done
