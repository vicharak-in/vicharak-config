# shellcheck shell=bash

__advanced_usb_tethering() {
	# Check if USB tethering service is active

	if systemctl is-active --quiet advanced-usb@tethering.service; then
		if yesno "USB tethering is currently enabled. Do you want to disable it?"; then
			if systemctl disable --now advanced-usb@tethering.service; then
				msgbox "USB tethering successfully disabled!"
			else
				msgbox "Failed to disable USB tethering."
			fi
		fi
	else
		if yesno "USB tethering is currently disabled. Do you want to enable it?"; then
			if systemctl enable --now advanced-usb@tethering.service; then
				msgbox "USB tethering successfully enabled!"
			else
				msgbox "Failed to enable USB tethering."
			fi
		fi
	fi
}

__advanced_usb_serial_tty() {
	# Placeholder for USB serial setup
	return
}

__advanced_usb() {
	menu_init
	menu_add __advanced_usb_tethering "Configure USB Tethering"
	# menu_add __advanced_usb_serial "USB Serial Device"

	menu_show "Advanced USB Features"
}
