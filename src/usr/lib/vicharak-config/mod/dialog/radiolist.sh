# shellcheck shell=bash

# shellcheck disable=SC2120
radiolist_init() {
	__parameter_count_check 0 "$@"

	export VICHARAK_CONFIG_RADIOLIST=()
	export VICHARAK_CONFIG_RADIOLIST_STATE_OLD=()
	export VICHARAK_CONFIG_RADIOLIST_STATE_NEW=()
}

radiolist_add() {
	__parameter_count_check 2 "$@"

	local item=$1
	local status=$2
	local tag="$((${#VICHARAK_CONFIG_RADIOLIST[@]} / 3))"

	__parameter_value_check "$status" "ON" "OFF"

	VICHARAK_CONFIG_RADIOLIST+=("$tag" "$item" "$status")

	if [[ $status == "ON" ]]; then
		VICHARAK_CONFIG_RADIOLIST_STATE_OLD+=("$tag")
	fi
}

radiolist_show() {
	__parameter_count_check 1 "$@"

	if ((${#VICHARAK_CONFIG_RADIOLIST[@]} == 0)); then
		return 2
	fi

	local output i
	if output="$(__dialog --radiolist "$1" "${VICHARAK_CONFIG_RADIOLIST[@]}" 3>&1 1>&2 2>&3 3>&-)"; then
		read -r -a VICHARAK_CONFIG_RADIOLIST_STATE_NEW <<<"$output"
		for i in $(seq 2 3 ${#VICHARAK_CONFIG_RADIOLIST[@]}); do
			VICHARAK_CONFIG_RADIOLIST[i]="OFF"
		done
		for i in "${VICHARAK_CONFIG_CHECKLIST_STATE_NEW[@]}"; do
			i="${i//\"/}"
			VICHARAK_CONFIG_RADIOLIST[i * 3 + 2]="ON"
		done
	else
		return 1
	fi
}

radiolist_getitem() {
	__parameter_count_check 1 "$@"

	echo "${VICHARAK_CONFIG_RADIOLIST[$((${1//\"/} * 3 + 1))]}"
}

radiolist_emptymsg() {
	__parameter_count_check 1 "$@"

	if ((${#VICHARAK_CONFIG_RADIOLIST[@]} == 0)); then
		msgbox "$1"
	fi
}
