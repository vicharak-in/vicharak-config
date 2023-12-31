# shellcheck shell=bash

# shellcheck disable=SC2120
menu_init() {
	__parameter_count_check 0 "$@"

	export VICHARAK_CONFIG_MENU=()
	export VICHARAK_CONFIG_MENU_CALLBACK=()
	export VICHARAK_CONFIG_MENU_SELECTED=
}

menu_add() {
	__parameter_count_check 2 "$@"
	if [[ "$1" != ":" ]]; then
		__parameter_type_check "$1" "function"
	fi

	local callback=$1
	local item=$2

	VICHARAK_CONFIG_MENU+=("$((${#VICHARAK_CONFIG_MENU[@]} / 2))" "$item")
	VICHARAK_CONFIG_MENU_CALLBACK+=("$callback")
}

# shellcheck disable=SC2120
menu_add_separator() {
	__parameter_count_check 0 "$@"

	menu_add : "========="
}

menu_emptymsg() {
	__parameter_count_check 1 "$@"

	if ((${#VICHARAK_CONFIG_MENU_CALLBACK[@]} == 0)); then
		msgbox "$1"
	fi
}

menu_getitem() {
	__parameter_count_check 1 "$@"

	echo "${VICHARAK_CONFIG_MENU[$((${1//\"/} * 2 + 1))]}"
}

menu_show() {
	__parameter_count_check 1 "$@"

	local item
	if item=$(__dialog --menu "$1" "${VICHARAK_CONFIG_MENU[@]}"); then
		VICHARAK_CONFIG_MENU_SELECTED="$(menu_getitem "$item")"
		push_screen "${VICHARAK_CONFIG_MENU_CALLBACK[$item]}"
	fi
}

menu_call() {
	__parameter_count_check 1 "$@"

	local item
	if item=$(__dialog --menu "$1" "${VICHARAK_CONFIG_MENU[@]}"); then
		VICHARAK_CONFIG_MENU_SELECTED="$(menu_getitem "$item")"
		${VICHARAK_CONFIG_MENU_CALLBACK[$item]}
	else
		return 1
	fi
}
