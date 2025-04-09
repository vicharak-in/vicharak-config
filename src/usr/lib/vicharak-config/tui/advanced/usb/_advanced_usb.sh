# shellcheck shell=bash

# This script executed for systemd service

# shellcheck source=src/usr/lib/vicharak-config/tui/advanced/usb/tethering.sh
source "/usr/lib/vicharak-config/tui/advanced/usb/tethering.sh"

if [[ "$1" == "tethering" ]]; then
	if [[ "$2" == "start" ]]; then
		__advanced_usb_tethering_enable
	elif [[ "$2" == "stop" ]]; then
		__advanced_usb_tethering_disable
	else
		exit 1
	fi
else
	exit 1
fi

