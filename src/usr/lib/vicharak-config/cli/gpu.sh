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

	sed -i 's/none/always/g' /etc/X11/xorg.conf.d/20-modesetting.conf
}

install_gpu() {
	__parameter_count_check 0 "$@"
	apt install /userdata/gpu/*.deb || true

	sed -i 's/always/none/g' /etc/X11/xorg.conf.d/20-modesetting.conf
}

enable_gpu_opengl() {
	__parameter_count_check 0 "$@"

	# shellcheck disable=SC2016
	echo '
#!/bin/bash

shopt -s nullglob

for path in /usr/lib/*/gl4es; do
	export LD_LIBRARY_PATH="${path}:${LD_LIBRARY_PATH}"
done

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
		rm /usr/bin/gl4es
	fi
}
