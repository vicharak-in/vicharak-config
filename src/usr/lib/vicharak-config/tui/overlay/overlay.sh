# shellcheck shell=bash

# shellcheck source=src/usr/lib/vicharak-config/mod/hwid.sh
source "/usr/lib/vicharak-config/mod/hwid.sh"
# shellcheck source=src/usr/lib/vicharak-config/mod/pkg.sh
source "/usr/lib/vicharak-config/mod/pkg.sh"
# shellcheck source=src/usr/lib/vicharak-config/mod/overlay.sh
source "/usr/lib/vicharak-config/mod/overlay.sh"

__overlay_install() {
	if ! __depends_package "Install 3rd party overlay" "gcc" "linux-headers-$(uname -r)"; then
		return
	fi

	if ! yesno "3rd party overlay could physically damage your system.
In addition, they may miss important metadata for vicharak-config to recognize correctly.
This means if you ever run 'Manage overlay' function again, your custom overlays
might be disabled, and you will have to manually reenable them.

Are you sure?"; then
		return
	fi

	local item basename err=0
	if ! item="$(fselect "$PWD")"; then
		return
	fi

	load_u-boot_setting

	basename="$(basename "$item")"

	case $basename in
	*.dtbo)
		cp "$item" "$U_BOOT_FDT_OVERLAYS_DIR/$basename"
		;;
	*.dts | *.dtso)
		basename="${basename%.dts}.dtbo"

		compile_dtb "$item" "$U_BOOT_FDT_OVERLAYS_DIR/$basename" || err=$?
		case $err in
		0) : ;;
		1)
			msgbox "Unable to preprocess the source code!"
			return
			;;
		2)
			msgbox "Unable to compile the source code!"
			return
			;;
		*)
			msgbox "Unknown error $err occured during compilation."
			return
			;;
		esac
		;;
	*)
		msgbox "Unknown file format: $basename"
		return
		;;
	esac

	if u-boot-update >/dev/null; then
		msgbox "Selected overlays will be enabled at next boot."
	else
		msgbox "Unable to update the boot config."
	fi
}

__overlay_filter_worker() {
	local temp="$1" overlay="$2" state title overlay_name

	if ! dtbo_is_compatible "$overlay"; then
		return
	fi

	exec 100>>"$temp"
	flock 100

	if [[ "$overlay" == *.dtbo ]]; then
		state="ON"
	elif [[ "$overlay" == *.dtbo.disabled ]]; then
		state="OFF"
	else
		return
	fi

	overlay_name="$(basename "$overlay" | sed -E "s/(.*\.dtbo).*/\1/")"
	mapfile -t title < <(parse_dtbo "$overlay" "title" "$overlay_name")

	echo -e "${title[0]}\0${state}\0${overlay_name}" >&100
}

__overlay_filter() {
	local temp="$1" nproc index
	local dtbos=("$U_BOOT_FDT_OVERLAYS_DIR"/*.dtbo*)

	if [[ ${#dtbos[@]} -eq 0 ]]; then
		return
	fi

	mapfile -t index < <(eval "echo {0..$((${#dtbos[@]} - 1))}" | tr ' ' '\n')
	nproc=$(nproc)

	for i in "${index[@]}"; do
		while (($(jobs -r | wc -l) > nproc)); do
			sleep 0.1
		done

		__overlay_filter_worker "$temp" "${dtbos[$i]}" &
		echo $((i * 100 / (${index[-1]} + 1)))
	done

	wait
}

# Array representing pin mapping according to Axon GPIO documentation format
# shellcheck disable=SC2034
axon_pins=(
"Function" 	"Pin#" 		"Pin#"		"Function"
"12V"		"1"    		"2"    		"GPIO0_B6"
"GND"         	"3"     	"4"    		"GPIO0_B5"
"5V"          	"5"     	"6"    		"GND"
"5V"          	"7"     	"8"    		"GND"
"GPIO2_C1"    	"9"    		"10"   		"GPIO2_B6"
"GPIO2_C0"   	"11"    	"12"   		"GPIO2_B7"
"GPIO0_C0"   	"13"    	"14"  		"3.3V"
"GND"        	"15"    	"16"   		"3.3V"
"GPIO1_D0"   	"17"    	"18"   		"GPIO1_D1"
"GPIO1_D3"   	"19"    	"20"   		"GPIO1_D2"
"GND"        	"21"    	"22"   		"3.3V"
"GPIO1_B3"   	"23"    	"24"   		"1.8V"
"GND"        	"25"    	"26"   		"GND"
"SARADC_4"   	"27"    	"28"   		"SARADC_3"
"SARADC_1"   	"29"    	"30"   		"SARADC_2"
)

# Array representing pin mapping according to Vaaman GPIO documentation format
# shellcheck disable=SC2034
vaaman_pins=(
"Function"	"Pin#"		"Pin#"		"Function"
"3.3V"		"1"		"2"		"5V"
"I2C7_SDA"	"3"		"4"		"5V"
"I2C7_SCL"	"5"		"6"		"GND"
"GPIO2_B3"	"7"		"8"		"GPIO4_C4"
"GND"		"9"		"10"		"GPIO4_C3"
"GPIO4_C2"	"11"		"12"		"GPIO4_A3"
"GPIO4_C6"	"13"		"14"		"GND"
"GPIO4_C5"	"15"		"16"		"GPIO4_D2"
"3.3V"		"17"		"18"		"GPIO4_D4"
"5V"		"19"		"20"		"GND"
"GND"		"21"		"22"		"GPIO4_D5"
"5V"		"23"		"24"		"GND"
"GND"		"25"		"26"		"ADC_IN0"
"GPIO2_A0"	"27"		"28"		"GPIO2_A1"
"GPIO2_B2"	"29"		"30"		"GND"
"GPIO2_B1"	"31"		"32"		"GPIO3_C0"
"GPIO2_B4"	"33"		"34"		"GND"
"GPIO4_A5"	"35"		"36"		"GPIO4_A4"
"GPIO4_D6"	"37"		"38"		"GPIO4_A6"
"GND"		"39"		"40"		"GPIO4_A7"
)

# Purpose: Highlight the pins that are used for the selected overlay
#	   Highlighted pins are wrapped with |* *| markers.
# Parameters:
#	$1 - Name of the array containing all pins
#	$2 - Name of the array containing exclusive pins (pins to be highlighted)
highlight_pins_aligned() {
	local -n pins_arr=$1
	local -n excl_arr=$2
	local total_length=${#pins_arr[@]}
	local cols=4
	local rows=$(( total_length / cols ))
	local i=0
	local output=""

	# Accessing 1D array as a simulated 2D array for displaying the pins correctly
	for ((row = 0; row < rows; row++)); do
		for ((col = 0; col < cols; col++)); do
			local pin="${pins_arr[i]}"
			local highlighted=false
			for excl in "${excl_arr[@]}"; do
				if [[ "$pin" == "$excl" ]]; then
					pin="|*${pin}*|"
					# shellcheck disable=SC2034
					highlighted=true
					break
				fi
			done

			# Printing only the headers, pin number columns and highlighted pins
			if [[ "$row" == 0 || "$col" == 1 || "$col" == 2 || "${pin:0:1}" == "|" ]]; then
				output+="${pin}\t"
			else
				output+="\t"
			fi
			((i++))
		done
		output+="\n"
	done

	echo -e "$output" | column -t -s $'\t'
}

# Purpose: Check which elements have an exclusive pin from Axon GPIO header
# Parameters:
#	$@ - Array elements to be checked
# Returns:
#	0 (true) if any element contains "GPIO", 1 (false) otherwise
contains_gpio() {
	local arr=("$@")
	for item in "${arr[@]}"; do
		if [[ "$item" == *GPIO* ]]; then
			return 0
	fi
	done
	return 1
}

# Purpose: Determine the board type, select appropriate pin mapping, and display
#          pinout with highlighted exclusive pins for selected overlays.
display_pinout(){
	BOARD_NAME=$(uname -a | awk '{print substr($4, 2)}');
	if [[ $BOARD_NAME == "vaaman" ]]; then
		all_pins="vaaman_pins"
	elif [[ $BOARD_NAME == "axon" ]]; then
		all_pins="axon_pins"
	else
		msgbox "You are trying to use a board which is not designed by Vicharak!!"
		return
	fi

	for i in "${VICHARAK_CONFIG_CHECKLIST_STATE_NEW[@]}"; do
		item="$(checklist_getitem "$i")"

		mapfile -t title < <(parse_dtbo "$U_BOOT_FDT_OVERLAYS_DIR/$item"* "title")
		mapfile -t exclusive < <(parse_dtbo "$U_BOOT_FDT_OVERLAYS_DIR/$item"* "exclusive")

		# Filter out "null" values from exclusive pins
		filtered=()
		for val in "${exclusive[@]}"; do
			[[ "$val" != "null" ]] && filtered+=("$val")
		done
		exclusive=("${filtered[@]}")

		# If exclusive pins contain GPIO pins, highlight them and show message box
		if [[ ${#exclusive[@]} -gt 0 ]] && contains_gpio "${exclusive[@]}"; then
			pin_table_highlighted=$(highlight_pins_aligned "$all_pins" exclusive)
			msgbox "Overlay: ${title[0]}

Exclusive Pins: ${exclusive[*]}

Pinout Table:
$pin_table_highlighted"
		fi
	done
}

__overlay_show() {
	local validation="${1:-true}"
	echo "Searching available overlays may take a while, please wait..." >&2
	load_u-boot_setting

	local temp
	temp="$(mktemp)"
	# shellcheck disable=SC2064
	trap "rm -f $temp" RETURN EXIT

	__overlay_filter "$temp" | gauge "Searching available overlays..." 0

	checklist_init
	# Bash doesn support IFS=$'\0'
	# Use array to emulate this
	local items=()
	mapfile -t items < <(sort "$temp" | tr $"\0" $"\n")
	while ((${#items[@]} >= 3)); do
		checklist_add "${items[0]/$'\n'/}" "${items[1]/$'\n'/}" "${items[2]/$'\n'/}"
		items=("${items[@]:3}")
	done

	checklist_emptymsg "Unable to find any compatible overlay under $U_BOOT_FDT_OVERLAYS_DIR."

	while true; do
		if ! checklist_show "Please select overlays:"; then
			return 1
		fi

		# If overlay_show not called from overlay_info,
		# only then display pinouts for selected overlays.
		is_overlay_info="${is_overlay_info:-0}"
		if [[ "$is_overlay_info" != "1" ]]; then
			display_pinout
		fi
		is_overlay_info=0

		if $validation; then
			return
		fi
	done
}

__overlay_validate() {
	local i item
	check_overlay_conflict_init
	for i in "${VICHARAK_CONFIG_CHECKLIST_STATE_NEW[@]}"; do
		item="$(checklist_getitem "$i")"
		if ! check_overlay_conflict "$U_BOOT_FDT_OVERLAYS_DIR/$item"*; then
			return 1
		fi

		local title package
		mapfile -t title < <(parse_dtbo "$U_BOOT_FDT_OVERLAYS_DIR/$item"* "title" "$(basename "$item")")
		mapfile -t package < <(parse_dtbo "$U_BOOT_FDT_OVERLAYS_DIR/$item"* "package")
		if [[ "${package[0]}" != "null" ]]; then
			if ! __depends_package "${title[0]}" "${package[@]}"; then
				msgbox "Failed to install required packages for '${title[0]}'."
				return 1
			fi
		fi
	done
}

__overlay_manage() {
	if ! __overlay_show __overlay_validate; then
		return
	fi

	disable_overlays

	local item
	for i in "${VICHARAK_CONFIG_CHECKLIST_STATE_NEW[@]}"; do
		item="$(checklist_getitem "$i")"
		mv "$U_BOOT_FDT_OVERLAYS_DIR/$item.disabled" "$U_BOOT_FDT_OVERLAYS_DIR/$item"
	done

	if u-boot-update >/dev/null; then
		msgbox "Selected overlays will be enabled at next boot."
	else
		msgbox "Unable to update the boot config."
	fi
}

__overlay_info() {
	is_overlay_info=1
	if ! __overlay_show; then
		return
	fi

	local item title category description exclusive package i
	for i in "${VICHARAK_CONFIG_CHECKLIST_STATE_NEW[@]}"; do
		item="$(checklist_getitem "$i")"
		mapfile -t title < <(parse_dtbo "$U_BOOT_FDT_OVERLAYS_DIR/$item"* "title")
		mapfile -t category < <(parse_dtbo "$U_BOOT_FDT_OVERLAYS_DIR/$item"* "category")

		mapfile -t exclusive < <(parse_dtbo "$U_BOOT_FDT_OVERLAYS_DIR/$item"* "exclusive")
		filtered=()
		for val in "${exclusive[@]}"; do
			[[ "$val" != "null" ]] && filtered+=("$val")
		done
		exclusive=("${filtered[@]}")

		mapfile -t package < <(parse_dtbo "$U_BOOT_FDT_OVERLAYS_DIR/$item"* "package")
		filtered=()
                for val in "${package[@]}"; do
                        [[ "$val" != "null" ]] && filtered+=("$val")
                done
                package=("${filtered[@]}")

		# Parse description and clean trailing null or whitespace
		description="$(parse_dtbo "$U_BOOT_FDT_OVERLAYS_DIR/$item"* "description" | sed 's/null.*//' | sed 's/[[:space:]]*$//')"

		if ((${#title[@]} == 1)) && [[ "${title[0]}" == "null" ]]; then
			title=("$item")
			description="This is a 3rd party overlay. No metadata is available."
		fi
		if ! yesno "Title: ${title[0]}

Category: ${category[0]}

Exclusive: ${exclusive[*]}

Package: ${package[*]}

Description:
	$description"; then
			break
		fi
	done
}

__overlay_reset() {
	if ! yesno "WARNING

All installed overlays will be reset to current running kernel's default.
All enabled overlays will be disabled.
Any overlay that is not shipped with the running kernel will be removed."; then
		return
	fi

	if reset_overlays "$(uname -r)" "$(get_soc_vendor)" "false"; then
		msgbox "Overlays has been reset to current running kernel's default."
	else
		msgbox "Unable to reset overlays"
	fi
}

__overlay() {
	VICHARAK_CONFIG_OVERLAY_WARNING="${VICHARAK_CONFIG_OVERLAY_WARNING:-true}"
	if [[ "$VICHARAK_CONFIG_OVERLAY_WARNING" == "true" ]] && ! yesno "WARNING

Overlays, by its nature, require \"hidden\" knowledge about the running device tree.
While major breakage is unlikely, this does mean that after kernel update, the overlay may cease to work.

If you accept the risk, select Yes to continue.
Otherwise, select No to go back to previous menu."; then
		return
	fi
	VICHARAK_CONFIG_OVERLAY_WARNING="false"

	load_u-boot_setting

	if [[ -n "${U_BOOT_FDT_OVERLAYS:-}" ]]; then
		msgbox \
			"Detected 'U_BOOT_FDT_OVERLAYS' in '/etc/default/u-boot'.
This usually happens when you want to customize your boot process.
To avoid potential conflicts, overlay feature is temporarily disabled until such customization is reverted."
		return
	fi

	menu_init
	menu_add __overlay_manage "Manage overlays"
	menu_add __overlay_info "View overlay info"
	menu_add __overlay_install "Install 3rd party overlay"
	menu_add __overlay_reset "Reset overlays"
	menu_show "Configure Device Tree Overlay"
}
