# shellcheck shell=bash

SECTOR=16000			# Sector on eMMC where U-Boot status is stored
OFFSET=$((SECTOR * 512))	# Convert sector to byte offset
CONSOLE_MAGIC="\x80\x00\x85"	# Magic value to toggle access to U-Boot CLI

# Read first 3 bytes at the OFFSET on eMMC and determine console status
get_uboot_console_status() {
	magic=$(sudo dd if=/dev/mmcblk0 bs=1 skip=$OFFSET count=3 2>/dev/null | hexdump -v -e '3/1 "%02x" "\n"')
	CONSOLE_MAGIC_STR=${CONSOLE_MAGIC//\\x/}

	# Determine console status based on magic value
	case "$magic" in
		"$CONSOLE_MAGIC_STR") 	echo "disabled" ;;
		*)			echo "enabled" ;;
	esac
}

# Write 3 bytes of zeros at the OFFSET to enable the console
enable_uboot_console() {
	printf "\x00\x00\x00" | dd of=/dev/mmcblk0 bs=1 seek=$OFFSET conv=notrunc 2>/dev/null
	msgbox "Boot Console Enabled"
}

# Write the "disabled magic" to the device
disable_uboot_console() {
	# shellcheck disable=SC2059
	printf "$CONSOLE_MAGIC" | dd of=/dev/mmcblk0 bs=1 seek=$OFFSET conv=notrunc 2>/dev/null
	msgbox "Boot Console Disabled"
}

# Provides a TUI for enabling/disabling U-Boot console
__uboot_console() {
	# Check the current console status and set default radio button states
	status=$(get_uboot_console_status)

	if [ "$status" = "disabled" ]; then
		default_disable=ON
		default_enable=OFF
	else
		default_disable=OFF
		default_enable=ON
	fi

	# Initialize the radiolist UI
	radiolist_init

	# Add options to the radiolist
	radiolist_add "Boot console enabled" "$default_enable"
	radiolist_add "Boot console disabled" "$default_disable"

	# Message to show if no options exist
	radiolist_emptymsg "No console options found."

	# Display the radiolist and allow user to select
	if ! radiolist_show "Select Boot console mode:\n        Enable or Disable the Boot console. Disabling blocks interrupts and access to Boot CLI."; then
		return
	fi

	selected_option="${VICHARAK_CONFIG_RADIOLIST_STATE_NEW[0]}"

	# Execute the appropriate function based on selection
	case "$selected_option" in
		0) enable_uboot_console;;
		1) disable_uboot_console;;
	esac
}
