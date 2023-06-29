# shellcheck shell=bash
# shellcheck disable=SC2086

__select_resolution_options() {
	local selected_resolution_option=""

	radiolist_init

	for i in "${resolution_option[@]}"; do
		radiolist_add "$i" "OFF"
	done

	if ! radiolist_show "Please select the resolution type:\nCustom: Enter custom resolution | Available: Select from available resolutions" || ((${#VICHARAK_CONFIG_RADIOLIST_STATE_NEW[@]} == 0)); then
		return
	fi

	selected_resolution_option="$(radiolist_getitem "${VICHARAK_CONFIG_RADIOLIST_STATE_NEW[0]}")"

	echo "$selected_resolution_option"
}

__select_dsi_monitor() {
	selected_dsi="${dsi_monitors[0]}"

	radiolist_init

	for i in "${dsi_monitors[@]}"; do
		radiolist_add "$i" "OFF"
	done

	if ! radiolist_show "Please select the DSI monitor:" || ((${#VICHARAK_CONFIG_RADIOLIST_STATE_NEW[@]} == 0)); then
		return
	fi

	selected_dsi="$(radiolist_getitem "${VICHARAK_CONFIG_RADIOLIST_STATE_NEW[0]}")"

	echo "$selected_dsi"
}

__select_external_monitor() {
	selected_external_monitor="${external_monitors[0]}"

	radiolist_init

	for i in "${external_monitors[@]}"; do
		radiolist_add "$i" "OFF"
	done

	if ! radiolist_show "Please select the external monitor:" || ((${#VICHARAK_CONFIG_RADIOLIST_STATE_NEW[@]} == 0)); then
		return
	fi

	selected_external_monitor="$(radiolist_getitem "${VICHARAK_CONFIG_RADIOLIST_STATE_NEW[0]}")"

	echo "$selected_external_monitor"
}

__select_display_interface() {
	display_interface=""
	if [[ "$selected_dsi" != "" ]]; then
		display_interface="$selected_dsi"
	elif [[ "$selected_external_monitor" != "" ]]; then
		display_interface="$selected_external_monitor"
	else
		msgbox "No display interface is selected."
		return
	fi
	echo "$display_interface"
}

__set_custom_resolution() {
	local custom_resolution=""

	if ! custom_resolution="$(inputbox "Please enter the custom resolution in the format of <width> <height> <rate>:" "1920 1080 60")" || [[ -z $custom_resolution ]]; then
		msgbox "Custom resolution not entered."
	fi

	modeline=$(gtf ${custom_resolution} | grep -oP '(?<="\s\s).+')
	modename=${custom_resolution// /_}
	if ! xrandr | grep -q $modename; then
		if ! xrandr --newmode $modename $modeline; then
			msgbox "Failed to add the custom resolution."
			return
		fi

		if ! xrandr --addmode $display_interface $modename; then
			msgbox "Failed to add the custom resolution."
			return
		fi
	fi

	if ! xrandr --output $display_interface --mode $modename; then
		msgbox "Failed to set the custom resolution."
		return
	fi

	msgbox "Successfully set the custom resolution."
	return
}

__set_from_available_resolutions() {
	local selected_resolution=""

	mapfile -t available_resolutions < <(xrandr | sed 1,2d | grep '^[ ]*[0-9]' | sed 's/\([0-9]\+\)x\([0-9i]\+\)[ ]*\([0-9]\+\).\([0-9]\+\).* / \1x\2  \3.\4Hz/')

	radiolist_init

	for i in "${available_resolutions[@]}"; do
		radiolist_add "$i" "OFF"
	done

	if ! radiolist_show "Please select the resolution:" || ((${#VICHARAK_CONFIG_RADIOLIST_STATE_NEW[@]} == 0)); then
		return
	fi

	selected_resolution="$(radiolist_getitem "${VICHARAK_CONFIG_RADIOLIST_STATE_NEW[0]}")"
	selected_resolution="$(echo "$selected_resolution" | awk '{print $1}')"

	if ! xrandr --output $display_interface --mode $selected_resolution; then
		msgbox "Failed to set the resolution."
		return
	fi

	msgbox "Successfully set the resolution."
	return
}

__advanced_set_display_resolution() {
	local active_monitors=() dsi_monitors=() external_monitors=()
	mapfile -t active_monitors < <(xrandr --listactivemonitors | tail -n +2 | awk '{print $4}')

	for i in "${active_monitors[@]}"; do
		if [[ "$i" =~ "DSI" ]]; then
			dsi_monitors+=("$i")
		else
			external_monitors+=("$i")
		fi
	done

	if ! ((${#external_monitors[@]})) && ! ((${#dsi_monitors[@]})); then
		msgbox "No active display is found.
Please check if the screen is connected and powered on."
		return
	fi

	local selected_dsi=""
	if ((${#dsi_monitors[@]} > 0)); then
		selected_dsi="$(__select_dsi_monitor)"
	fi

	local selected_external_monitor=""
	if ((${#external_monitors[@]} > 0)); then
		selected_external_monitor="$(__select_external_monitor)"
	fi

	# Choose between custom resolution or available resolutions
	resolution_option=("Custom" "Available")
	local selected_resolution_option=""
	if [[ "$selected_dsi" != "" ]] || [[ "$selected_external_monitor" != "" ]]; then
		selected_resolution_option="$(__select_resolution_options)"
	else
		msgbox "No resolution option was selected.\nSelecting Available by default."
		selected_resolution_option="Available"
	fi

	local display_interface=""
	display_interface="$(__select_display_interface)"

	if [[ "$selected_resolution_option" == "Custom" ]]; then
		__set_custom_resolution
	else
		__set_from_available_resolutions
	fi
}

__advanced_display() {
	menu_init
	menu_add __advanced_set_display_resolution "Set display resolution"

	menu_show "Advanced Display"
}
