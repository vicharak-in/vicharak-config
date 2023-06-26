# shellcheck shell=bash

PATH_GL4ES="/usr/lib/gl4es"

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
	apt install /userdata/gpu/*.deb || true
}

fixup_ld_library_path() {
	# remove colon at the end if it exists
	ld_library_path=${1%:}

	# remove colon at the beginning if it exists
	ld_library_path=${ld_library_path#:}
}

enable_gpu() {
	__parameter_count_check 0 "$@"

	if [ -d "$PATH_GL4ES" ]; then
		if grep -q "LD_LIBRARY_PATH=" /etc/environment; then
			ld_library_path=$(grep "LD_LIBRARY_PATH" /etc/environment | sed 's/export LD_LIBRARY_PATH=//g')
			ld_library_path="$PATH_GL4ES:$ld_library_path"

			# fixup LD_LIBRARY_PATH
			fixup_ld_library_path "$ld_library_path"

			sed -i "/LD_LIBRARY_PATH/d" /etc/environment
		else
			ld_library_path="$PATH_GL4ES"
		fi

		echo "export LD_LIBRARY_PATH=$ld_library_path" >>/etc/environment
		source /etc/environment

		# Enable GL4ES library inside /etc/ld.so.conf.d
		if [ ! -f /etc/ld.so.conf.d/gl4es.conf ]; then
			touch /etc/ld.so.conf.d/gl4es.conf
		fi
		echo "$PATH_GL4ES" >/etc/ld.so.conf.d/gl4es.conf

		ldconfig
	else
		echo "GL4ES library not found" >&2

		exit 1
	fi
}

disable_gpu() {
	__parameter_count_check 0 "$@"

	if grep -q "$PATH_GL4ES" /etc/environment; then
		if grep -q "LD_LIBRARY_PATH=" /etc/environment; then
			ld_library_path=$(grep "LD_LIBRARY_PATH" /etc/environment | sed 's/export LD_LIBRARY_PATH=//g')
			ld_library_path=${ld_library_path//$PATH_GL4ES/}

			# fixup LD_LIBRARY_PATH
			fixup_ld_library_path "$ld_library_path"

			sed -i "/LD_LIBRARY_PATH/d" /etc/environment
			echo "export LD_LIBRARY_PATH=$ld_library_path" >>/etc/environment

			source /etc/environment
		fi

		# Disable GL4ES library inside /etc/ld.so.conf.d
		if [ -f /etc/ld.so.conf.d/gl4es.conf ]; then
			rm -f /etc/ld.so.conf.d/gl4es.conf

			ldconfig
		fi
	fi
}
