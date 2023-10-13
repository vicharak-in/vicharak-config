# shellcheck shell=bash

# Provides remove_packages
# shellcheck disable=SC1091
source "/usr/lib/vicharak-config/mod/pkg.sh"

ALLOWED_VICHARAK_CONFIG_FUNC+=("request_reboot" "headless" "no_fail")

VICHARAK_CONFIG_REBOOT="false"

headless() {
	local i
	for i in /sys/class/drm/*/status; do
		if [[ "$(cat "$i")" == "connected" ]] && [[ ! ${i} =~ eDP ]]; then
			return 1
		fi
	done
}

vicharak_config_allowed_func() {
	if [[ $(type -t "$1") != function ]] || ! __in_array "$1" "${ALLOWED_VICHARAK_CONFIG_FUNC[@]}" >/dev/null; then
		echo "'$1' is not an allowed command."
		return 1
	fi
}

request_reboot() {
	VICHARAK_CONFIG_REBOOT="${1:-true}"
}

no_fail() {
	no_fail="${1:-true}"
}

process_config() {
	local argv no_fail="false"
	while read -r; do
		read -r -a argv <<<"$REPLY"
		if [[ -z ${argv+IS_SET} ]]; then
			local argv=("")
		fi

		case "${argv[0]}" in
		\#* | "")
			continue
			;;
		if | if_not)
			if ! vicharak_config_allowed_func "${argv[1]}"; then
				continue
			elif [[ "${argv[0]}" == "if" ]] && ! "${argv[1]}"; then
				continue
			elif [[ "${argv[0]}" == "if_not" ]] && "${argv[1]}"; then
				continue
			else
				argv=("${argv[@]:2}")
			fi
			;;
		esac

		if vicharak_config_allowed_func "${argv[0]}"; then
			echo "Running ${argv[0]} with" "${argv[@]:1}" "..."
			if $DEBUG; then
				echo "${argv[*]}"
			else
				"${argv[@]}" || "$no_fail"
			fi
		fi
	done < <(grep "" "$1")
}

__on_boot() {
	__parameter_count_check 0 "$@"

	local ext_user_conf_dir="/usr/lib/vicharak-config/conf.d" distro_conf_dir="/usr/lib/vicharak-config/conf.d/on_boot"

	for i in "$distro_conf_dir"/*.conf "$ext_user_conf_dir/before.txt" "$ext_user_conf_dir/config.txt" "$ext_user_conf_dir/after.txt"; do
		if [[ -e "$i" ]]; then
			process_config "$i"
		fi
	done

	rm -f "$ext_user_conf_dir/before.txt" "$ext_user_conf_dir/after.txt"

	if [[ "$VICHARAK_CONFIG_REBOOT" == "true" ]]; then
		reboot
	fi
}
