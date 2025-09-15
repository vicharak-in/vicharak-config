# shellcheck shell=bash

# shellcheck source=src/usr/lib/vicharak-config/tui/advanced/uboot/console.sh
source "/usr/lib/vicharak-config/tui/advanced/uboot/console.sh"

__advanced_uboot() {
	menu_init
	menu_add __uboot_console "Boot Console Access (Enable/Disable)"
	menu_show "Please select an option below:"
}
