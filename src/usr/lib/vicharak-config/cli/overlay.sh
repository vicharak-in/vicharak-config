# shellcheck shell=bash
# shellcheck disable=SC1090

ALLOWED_VICHARAK_CONFIG_FUNC+=("__overlay_install" "__overlay_list" "__overlay_manage" "__overlay_reset" "__overlay_info")

source "${ROOT_PATH}/usr/lib/vicharak-config/mod/hwid.sh"
source "${ROOT_PATH}/usr/lib/vicharak-config/mod/pkg.sh"
source "${ROOT_PATH}/usr/lib/vicharak-config/mod/overlay.sh"
source "${ROOT_PATH}/usr/lib/vicharak-config/mod/dialog/basic.sh"
source "${ROOT_PATH}/usr/lib/vicharak-config/mod/dialog/checklist.sh"

__check_sudo() {
	if ((EUID != 0)); then
		echo "Must be run as root, please use 'sudo'." >&2
		return 1
	fi
}

__overlay_install() {
	__check_sudo "$0"
	__parameter_count_check 1 "$@"

	if ! __depends_package "Install 3rd party overlay" "gcc" "linux-headers-$(uname -r)"; then
		return
	fi

	if ! CLI=1 yesno "3rd party overlay could physically damage your system.
In addition, they may miss important metadata for vicharak-config to recognize correctly.
This means if you ever run 'Manage overlay' function again, your custom overlays
might be disabled, and you will have to manually reenable them.

Are you sure? (yes/no)"; then
		return
	fi

	local item basename err=0
	item="$1"

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
			echo Unable to preprocess the source code! >&2
			return
			;;
		2)
			echo Unable to compile the source code! >&2
			return
			;;
		*)
			echo Unknown error $err occured during compilation. >&2
			return
			;;
		esac
		;;
	*)
		echo Unknown file format: "${basename}" >&2
		return
		;;
	esac

	if u-boot-update >/dev/null; then
		echo Selected overlays will be enabled at next boot. >&2
	else
		echo Unable to update the boot config. >&2
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
	local temp="$1" index
	local dtbos=("$U_BOOT_FDT_OVERLAYS_DIR"/*.dtbo*)

	if [[ ${#dtbos[@]} -eq 0 ]]; then
		return
	fi

	mapfile -t index < <(eval "echo {0..$((${#dtbos[@]} - 1))}" | tr ' ' '\n')

	for i in "${index[@]}"; do
		__overlay_filter_worker "$temp" "${dtbos[$i]}"
	done
}

__overlay_list() {
	echo "Searching available overlays may take a while, please wait..." >&2
	load_u-boot_setting

	local temp
	temp="$(mktemp)"
	# shellcheck disable=SC2064
	trap "rm -f $temp" RETURN EXIT

	echo "Searching available overlays..." >&2
	__overlay_filter "$temp"

	# shellcheck disable=SC2119
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
}

__overlay_show() {
	local validation="${1:-true}"

	__overlay_list

	while true; do
		if ! checklist_show_cli "Enter the numbers of overlays to toggle (e.g., 1 2 3) or 'q' to quit:"; then
			return 1
		fi

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
		if ! CLI=1 check_overlay_conflict "$U_BOOT_FDT_OVERLAYS_DIR/$item"*; then
			return 1
		fi

		local title package
		mapfile -t title < <(parse_dtbo "$U_BOOT_FDT_OVERLAYS_DIR/$item"* "title" "$(basename "$item")")
		mapfile -t package < <(parse_dtbo "$U_BOOT_FDT_OVERLAYS_DIR/$item"* "package")
		if [[ "${package[0]}" != "null" ]]; then
			if ! __depends_package "${title[0]}" "${package[@]}"; then
				echo "Failed to install required packages for '${title[0]}'." >&2
				return 1
			fi
		fi
	done
}

__overlay_manage() {
	__check_sudo "$0"

	if ! __overlay_show __overlay_validate; then
		return
	fi

	disable_overlays

	local item
	for i in "${VICHARAK_CONFIG_CHECKLIST_STATE_OLD[@]}"; do
		item="$(checklist_getitem "$i")"
		if [ -e "$U_BOOT_FDT_OVERLAYS_DIR/$item.disabled" ]; then
			mv "$U_BOOT_FDT_OVERLAYS_DIR/$item.disabled" "$U_BOOT_FDT_OVERLAYS_DIR/$item"
		fi
	done
	for i in "${VICHARAK_CONFIG_CHECKLIST_STATE_NEW[@]}"; do
		item="$(checklist_getitem "$i")"
		if [ -e "$U_BOOT_FDT_OVERLAYS_DIR/$item.disabled" ]; then
			mv "$U_BOOT_FDT_OVERLAYS_DIR/$item.disabled" "$U_BOOT_FDT_OVERLAYS_DIR/$item"
		elif [ -e "$U_BOOT_FDT_OVERLAYS_DIR/$item" ]; then
			mv "$U_BOOT_FDT_OVERLAYS_DIR/$item" "$U_BOOT_FDT_OVERLAYS_DIR/$item.disabled"
		fi
	done

	if u-boot-update >/dev/null; then
		echo Selected overlays will be enabled at next boot. >&2
	else
		echo Unable to update the boot config. >&2
	fi
}

__overlay_info() {
	__overlay_list

	checklist_show_cli "Please enter the numbers of overlay for more information, or 'q' to quit:"

	local item title category description exclusive package i
	for i in "${VICHARAK_CONFIG_CHECKLIST_STATE_NEW[@]}"; do
		item="$(checklist_getitem "$i")"

		mapfile -t title < <(parse_dtbo "$U_BOOT_FDT_OVERLAYS_DIR/$item"* "title")
		mapfile -t category < <(parse_dtbo "$U_BOOT_FDT_OVERLAYS_DIR/$item"* "category")
		mapfile -t exclusive < <(parse_dtbo "$U_BOOT_FDT_OVERLAYS_DIR/$item"* "exclusive")
		mapfile -t package < <(parse_dtbo "$U_BOOT_FDT_OVERLAYS_DIR/$item"* "package")
		description="$(parse_dtbo "$U_BOOT_FDT_OVERLAYS_DIR/$item"* "description")"
		if ((${#title[@]} == 1)) && [[ "${title[0]}" == "null" ]]; then
			title=("$item")
			description="This is a 3rd party overlay. No metadata is available."
		fi
		echo "Overlay number ${i}
Title: ${title[0]}
Category: ${category[0]}
Exclusive: ${exclusive[*]}
Package: ${package[*]}
Description:

$description

" >&2
	done
}

__overlay_reset() {
	__check_sudo "$0"

	if ! CLI=1 yesno "WARNING

All installed overlays will be reset to current running kernel's default.
All enabled overlays will be disabled.
Any overlay that is not shipped with the running kernel will be removed.

Enter (yes/no) to continue.
"; then
		return
	fi

	if reset_overlays "$(uname -r)" "$(get_soc_vendor)" "false"; then
		if u-boot-update >/dev/null; then
			echo "Overlays has been reset to current running kernel's default." >&2
		fi
	else
		echo "Unable to reset overlays" >&2
	fi

}
