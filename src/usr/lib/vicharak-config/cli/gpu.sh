# shellcheck shell=bash
# shellcheck disable=SC2154

uninstall_gpu() {
	__parameter_count_check 0 "$@"

	lib_mali=$(dpkg -l | grep "libmali" | awk '{print $2}')

	while read -r line; do
		if grep -q "dbgsym" <<<"$line"; then
			continue
		fi
		apt purge "$line" -y
	done <<<"$lib_mali"
}

install_gpu() {
	__parameter_count_check 0 "$@"

	if [ ! -d "/userdata/gpu" ]; then
		msgbox "The directory '/userdata/gpu' does not exists!\nSomething went wrong."
		return
	fi
	apt install /userdata/gpu/*.deb || true
}
