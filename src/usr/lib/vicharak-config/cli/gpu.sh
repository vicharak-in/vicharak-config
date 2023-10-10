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

	if [ -d /userdata/gpu ]; then
		msgbox "The directory '/userdata/gpu' does not exists!\nSomething went wrong."
		return
	fi
	apt install /userdata/gpu/*.deb || true
}

enable_gpu_opengl() {
	__parameter_count_check 0 "$@"

	# shellcheck disable=SC2016
	echo '
#!/bin/bash

shopt -s nullglob

export LD_LIBRARY_PATH="/usr/lib/gl4es:${LD_LIBRARY_PATH}"

exec "$@"
' >/usr/bin/gl4es

	if [ -f /usr/bin/gl4es ]; then
		chmod +x /usr/bin/gl4es
	else
		echo "Failed to create /usr/bin/gl4es"
	fi
}

disable_gpu_opengl() {
	__parameter_count_check 0 "$@"

	if [ -f /usr/bin/gl4es ]; then
		rm -f /usr/bin/gl4es
	fi
}
