# shellcheck shell=bash

# shellcheck source=src/usr/lib/vicharak-config/mod/dialog/basic.sh
source "/usr/lib/vicharak-config/mod/dialog/basic.sh"
# shellcheck source=src/usr/lib/vicharak-config/mod/dialog/menu.sh
source "/usr/lib/vicharak-config/mod/dialog/menu.sh"
# shellcheck source=src/usr/lib/vicharak-config/mod/dialog/checklist.sh
source "/usr/lib/vicharak-config/mod/dialog/checklist.sh"
# shellcheck source=src/usr/lib/vicharak-config/mod/dialog/radiolist.sh
source "/usr/lib/vicharak-config/mod/dialog/radiolist.sh"
# shellcheck source=src/usr/lib/vicharak-config/mod/dialog/select.sh
source "/usr/lib/vicharak-config/mod/dialog/select.sh"

VICHARAK_CONFIG_SCREEN=()

register_screen() {
	__parameter_count_check 1 "$@"
	if [[ "$1" != ":" ]]; then
		__parameter_type_check "$1" "function"
	fi

	VICHARAK_CONFIG_SCREEN+=("$1")
}

# shellcheck disable=SC2120
unregister_screen() {
	__parameter_count_check 0 "$@"

	VICHARAK_CONFIG_SCREEN=("${VICHARAK_CONFIG_SCREEN[@]:0:$((${#VICHARAK_CONFIG_SCREEN[@]} - 1))}")
}

push_screen() {
	__parameter_count_check 1 "$@"

	register_screen "$1"
	register_screen ":"
}

switch_screen() {
	__parameter_count_check 1 "$@"

	unregister_screen
	push_screen "$1"
}

tui_start() {
	__parameter_count_check 1 "$@"
	__parameter_type_check "$1" "function"

	if ! infocmp "$TERM" &>/dev/null; then
		echo "Could not find terminfo for $TERM." >&2
		return 1
	fi

	register_screen "$1"
	while ((${#VICHARAK_CONFIG_SCREEN[@]} != 0)); do
		${VICHARAK_CONFIG_SCREEN[-1]}
		unregister_screen
	done
}
