# shellcheck shell=bash

HOTSPOT_SERVICE="vicharak-config.hotspot.service"
HOTSPOT_SCRIPT="/usr/lib/vicharak-config/tui/comm/hotspot/start_hotspot.sh"

__hotspot_enable_recovery() {
	sudo systemctl enable "$HOTSPOT_SERVICE"
	sudo systemctl start "$HOTSPOT_SERVICE"
	msgbox "Recovery button hotspot enabled"
}

__hotspot_disable_recovery() {
	sudo systemctl stop "$HOTSPOT_SERVICE"
	sudo systemctl disable "$HOTSPOT_SERVICE"
	msgbox "Recovery button hotspot disabled"
}

__hotspot_start_now() {
	sudo "$HOTSPOT_SCRIPT"
	msgbox "Hotspot started manually"
}

__hotspot_edit_credentials() {
	SSID=$(inputbox "Enter SSID" "HOTSPOT")
	PASS=$(inputbox "Enter Password (min 8 chars)" "12345678")

	if [ -z "$SSID" ] || [ -z "$PASS" ]; then
		msgbox "Invalid input"
		return
	fi

	sudo sed -i "s/^SSID=.*/SSID=\"$SSID\"/" "$HOTSPOT_SCRIPT"
	sudo sed -i "s/^PASSWORD=.*/PASSWORD=\"$PASS\"/" "$HOTSPOT_SCRIPT"

	msgbox "Credentials updated"
}

__hotspot() {
	menu_init

	menu_add __hotspot_recovery_enable  "Enable via Recovery Button"
	menu_add __hotspot_recovery_disable "Disable Recovery Button"

	menu_add __hotspot_manual           "Start Hotspot Now"
	menu_add __hotspot_edit             "Edit Credentials"

	menu_show "Hotspot Configuration"
}
