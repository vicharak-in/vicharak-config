# shellcheck shell=bash

VICHARAK_CONFIG_DIALOG=${VICHARAK_CONFIG_DIALOG:-"whiptail"}

__dialog() {
	local box="$1" text="$2" height width listheight
	shift 2
	height="$(__check_terminal | cut -d ' ' -f 1)"
	width="$(__check_terminal | cut -d ' ' -f 2)"
	case $box in
	--menu)
		listheight=0
		;;
	--checklist | --radiolist)
		listheight=$((height - 8))
		;;
	esac

	if ((height < 8)); then
		echo "TTY height needs to be at least 8 for TUI mode to work, currently is '$height'." >&2
		return 1
	fi

	if $DEBUG; then
		local backtitle=("--backtitle" "${VICHARAK_CONFIG_SCREEN[*]}")
	else
		local backtitle=()
	fi

	$VICHARAK_CONFIG_DIALOG --title "VICHARAK_CONFIG" ${backtitle:+"${backtitle[@]}"} --notags "$box" "$text" "$height" "$width" ${listheight:+"$listheight"} "$@"
}

yesno() {
	__parameter_count_check 1 "$@"

	if [ -z "${CLI}" ]; then
		__dialog --yesno "$1" 3>&1 1>&2 2>&3 3>&-
	else
		echo "$1" >&2
		read -r input

		if [[ "$input" == "yes" ]]; then
			return 0
		elif [[ "$input" == "no" ]]; then
			return 1
		else
			echo "Please enter 'yes' or 'no'." >&2
			CLI=1 yesno_cli "$1"
		fi
	fi
}

msgbox() {
	__parameter_count_check 1 "$@"

	if [ -z "${CLI}" ]; then
		__dialog --msgbox "$1"
	else
		echo "$1" >&2
	fi
}

inputbox() {
	__parameter_count_check 2 "$@"

	__dialog --inputbox "$1" "$2" 3>&1 1>&2 2>&3 3>&-
}

passwordbox() {
	__parameter_count_check 1 "$@"

	__dialog --passwordbox "$1" 3>&1 1>&2 2>&3 3>&-
}

gauge() {
	__parameter_count_check 2 "$@"

	__dialog --gauge "$1" "$2"
}
