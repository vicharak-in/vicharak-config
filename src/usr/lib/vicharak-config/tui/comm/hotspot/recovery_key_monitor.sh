#!/bin/bash

ADC_PATH="/sys/bus/iio/devices/iio:device0/in_voltage1_raw"
THRESHOLD=512
SLEEP_INTERVAL=0.2

LAST_STATE=1   # 1 = not pressed, 0 = pressed

echo "[KEY_MONITOR] Started"

while true; do
    if [ ! -f "$ADC_PATH" ]; then
        echo "[KEY_MONITOR] ADC path missing!"
        sleep 1
        continue
    fi

    ADC_VALUE=$(cat "$ADC_PATH")

    if [ "$ADC_VALUE" -lt "$THRESHOLD" ]; then
        CURRENT_STATE=0
    else
        CURRENT_STATE=1
    fi

    # Detect falling edge (button press event)
    if [ "$LAST_STATE" -eq 1 ] && [ "$CURRENT_STATE" -eq 0 ]; then
        echo "[KEY_MONITOR] Key Press Detected!"

        # Trigger hotspot script
        /usr/lib/vicharak-config/tui/comm/hotspot/start_hotspot.sh &
    fi

    LAST_STATE=$CURRENT_STATE

    sleep $SLEEP_INTERVAL
done
