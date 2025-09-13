# shellcheck shell=bash

# shellcheck source=src/usr/lib/vicharak-config/tui/advanced/docker/docker.sh
source "/usr/lib/vicharak-config/tui/advanced/docker/docker.sh"
# shellcheck source=src/usr/lib/vicharak-config/tui/advanced/gpu/gpu.sh
source "/usr/lib/vicharak-config/tui/advanced/gpu/gpu.sh"
# shellcheck source=src/usr/lib/vicharak-config/tui/advanced/ssh/ssh.sh
source "/usr/lib/vicharak-config/tui/advanced/ssh/ssh.sh"
# shellcheck source=src/usr/lib/vicharak-config/tui/advanced/display/display.sh
source "/usr/lib/vicharak-config/tui/advanced/display/display.sh"
# shellcheck source=src/usr/lib/vicharak-config/tui/advanced/vnc/vncserver.sh
source "/usr/lib/vicharak-config/tui/advanced/vnc/vncserver.sh"
# shellcheck source=src/usr/lib/vicharak-config/tui/advanced/usb/usb.sh
source "/usr/lib/vicharak-config/tui/advanced/usb/usb.sh"
# shellcheck source=src/usr/lib/vicharak-config/tui/advanced/uboot/main.sh
source "/usr/lib/vicharak-config/tui/advanced/uboot/main.sh"
# shellcheck source=src/usr/lib/vicharak-config/tui/advanced/backup/backup.sh
source "/usr/lib/vicharak-config/tui/advanced/backup/backup.sh"

__advanced() {
	menu_init
	#menu_add __advanced_docker          "Docker"
	menu_add __advanced_gpu "Mali GPU"
	menu_add __advanced_display "Display Options"
	menu_add __advanced_vncserver "VNC Server"
	#menu_add __advanced_ssh             "SSH"
	menu_add __advanced_usb "USB Advanced features"
	menu_add __advanced_uboot "Boot Settings"
	menu_add __advanced_backup "Board Backup"
	menu_show "Please select an option below:"
}
