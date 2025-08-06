# shellcheck shell=bash

__kernel() {
	local CONFIG_FILE="/boot/extlinux/extlinux.conf"
	local UPDATE_FILE="/etc/default/u-boot"
	local default_label
	default_label=$(awk '/^default/ {print $2}' "$CONFIG_FILE")

	# Extract all kernel versions from extlinux.conf filtering the lines containing "menu label"
	mapfile -t kernels < <(grep "menu label" "$CONFIG_FILE" | sed -n 's/.*Linux Kernel \(.*\)/\1/p')

	radiolist_init

	# Variable to track which is currently set default kernel
	local is_current_kernel="OFF"

	for kernel in "${kernels[@]}"; do
		local label
		label=$(awk -v k="$kernel" '$0 ~ "Linux Kernel " k { print prev } { prev = $0 }' "$CONFIG_FILE" | awk '{print $2}')

		# Mark the current default kernel as ON(*) in the UI
		if [[ "$label" == "$default_label" ]]; then
			is_current_kernel="ON"
		fi

		# Add a new entry to radiolist
		radiolist_add "Linux Kernel $kernel" "$is_current_kernel"

		# Reset selection flag
		is_current_kernel="OFF"
	done

	# Debug message if no kernels were found
	radiolist_emptymsg "No kernels found in $CONFIG_FILE."

	# Display UI screen for kernel selection
	radiolist_show "Please select a kernel version:"

	if [[ ${#VICHARAK_CONFIG_RADIOLIST_STATE_NEW[@]} -gt 0 ]]; then
		local selected_index="${VICHARAK_CONFIG_RADIOLIST_STATE_NEW[0]}"
		local selected_kernel
		selected_kernel="$(radiolist_getitem "$selected_index")"
		local selected_kernel_label
		selected_kernel_label=$(awk -v k="$selected_kernel" '$0 ~ k { print prev } { prev = $0 }' "$CONFIG_FILE" | awk '{print $2}')

		if [[ -n "$selected_kernel_label" ]]; then
			# Change U_BOOT_DEFAULT in /etc/default/u-boot
			sed -i 's/^#\?\s*U_BOOT_DEFAULT=.*/U_BOOT_DEFAULT="'"$selected_kernel_label"'"/' "$UPDATE_FILE"
			# Update extlinux.conf file according to changes made in /etc/default/u-boot
			if u-boot-update; then
				msgbox "$selected_kernel is selected and will be applied on next boot."
				return 0
			else
				echo "Error: u-boot-update failed."
				return 1
			fi
		else
			echo "Error: Could not determine label for selected kernel."
			return 1
		fi
	else
		echo "No kernel selected."
		return 1
	fi
}
