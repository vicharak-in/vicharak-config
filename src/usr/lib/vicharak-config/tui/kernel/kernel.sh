# shellcheck shell=bash

# shellcheck source=src/usr/lib/vicharak-config/mod/systemd-boot.sh
source "/usr/lib/vicharak-config/mod/systemd-boot.sh"

__kernel_systemd_boot() {
	local esp conf id version state current selected
	esp="$(get_esp)"

	current="$(get_systemd_boot_default_entry)"

	radiolist_init
	for conf in "$esp"/loader/entries/*.conf; do
		[[ -f "$conf" ]] || continue
		id="$(basename "$conf" .conf)"
		version="$(awk '/^version/{print $2; exit}' "$conf")"
		state="OFF"
		[[ "$id" == "$current" ]] && state="ON"
		radiolist_add "$id (Linux Kernel $version)" "$state"
	done
	radiolist_emptymsg "No systemd-boot entries found under $esp/loader/entries."

	if ! radiolist_show "Please select the kernel to boot by default:"; then
		return 1
	fi
	if ((${#VICHARAK_CONFIG_RADIOLIST_STATE_NEW[@]} == 0)); then
		return 1
	fi

	selected="$(radiolist_getitem "${VICHARAK_CONFIG_RADIOLIST_STATE_NEW[0]}")"
	selected="${selected%% *}"

	if set_systemd_boot_default "$selected"; then
		msgbox "$selected is selected and will boot by default on next boot."
		return 0
	else
		msgbox "Unable to update the boot config."
		return 1
	fi
}

__kernel() {
	if [[ "$(get_boot_mode)" == "systemd-boot" ]]; then
		__kernel_systemd_boot
		return
	fi

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
