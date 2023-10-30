# shellcheck shell=bash

# shellcheck source=src/usr/lib/vicharak-config/mod/tui.sh
source "/usr/lib/vicharak-config/mod/tui.sh"

# shellcheck source=src/usr/lib/vicharak-config/tui/overlay/overlay.sh
source "/usr/lib/vicharak-config/tui/overlay/overlay.sh"
# shellcheck source=src/usr/lib/vicharak-config/tui/comm/comm.sh
source "/usr/lib/vicharak-config/tui/comm/comm.sh"
# shellcheck source=src/usr/lib/vicharak-config/tui/hardware/hardware.sh
source "/usr/lib/vicharak-config/tui/hardware/hardware.sh"
# shellcheck source=src/usr/lib/vicharak-config/tui/local/local.sh
source "/usr/lib/vicharak-config/tui/local/local.sh"
# shellcheck source=src/usr/lib/vicharak-config/tui/system/system.sh
source "/usr/lib/vicharak-config/tui/system/system.sh"
# shellcheck source=src/usr/lib/vicharak-config/tui/advanced/advanced.sh
source "/usr/lib/vicharak-config/tui/advanced/advanced.sh"
# shellcheck source=src/usr/lib/vicharak-config/tui/user/user.sh
source "/usr/lib/vicharak-config/tui/user/user.sh"

if $DEBUG; then
	# shellcheck source=src/usr/lib/vicharak-config/tui/test/test.sh
	source "/usr/lib/vicharak-config/tui/test/test.sh"
fi

__tui_about() {
	msgbox "vicharak-config - Vicharak system setup utility

Copyright $(date +%Y) Vicharak Computers LLP"
}

__tui_main() {
	menu_init
	menu_add __system "System Maintaince"
	menu_add __hardware "Hardware"
	menu_add __overlay "Overlays"
	menu_add __comm "Connectivity"
	menu_add __advanced "Advanced Options"
	menu_add __user "User Settings"
	menu_add __local "Localization"
	if $DEBUG; then
		menu_add __advanced "Common advanced Options"
		menu_add __test "TUI Test"
	fi
	menu_add __tui_about "About"
	menu_show "Please select an option below:"
}
