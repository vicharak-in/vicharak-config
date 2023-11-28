# shellcheck shell=bash

shopt -s nullglob

install_vncserver() {
	__parameter_count_check 0 "$@"
	apt-get update -y
	apt-get install xfonts-base tightvncserver autocutsel -y
}

uninstall_vncserver() {
	__parameter_count_check 0 "$@"

	disable_vncserver "$@"
	apt-get purge tightvncserver -y
}

enable_vncserver() {
	__parameter_count_check 0 "$@"

	if systemctl is-enabled vncserver.service >/dev/null 2>&1; then
		# check if vncserver is running
		if systemctl is-active vncserver.service >/dev/null 2>&1; then
			systemctl stop vncserver.service >/dev/null 2>&1
		else
			systemctl disable --now vncserver.service >/dev/null 2>&1
		fi
	fi

	if [ -e "/tmp/.X[0-9]*-lock" ]; then
		rm -f "/tmp/.X[0-9]*-lock"
	fi

	if [ -d "/tmp/.X11-unix" ]; then
		rm -rf "/tmp/.X11-unix"
	fi

	local user
	user=$(logname)

	local files
	files=("/home/${user}/.vnc/${user}:"[0-9]*)

	if [ ${#files[@]} -gt 0 ]; then
		rm -rf "${files[@]}"
	fi

	systemctl enable --now vncserver.service >/dev/null 2>&1
	systemctl start vncserver.service >/dev/null 2>&1
}

disable_vncserver() {
	__parameter_count_check 0 "$@"

	if [ -e "/tmp/.X[0-9]*-lock" ]; then
		rm -f "/tmp/.X[0-9]*-lock"
	fi

	if [ -d "/tmp/.X11-unix" ]; then
		rm -rf "/tmp/.X11-unix"
	fi

	local user
	user=$(logname)

	local files
	files=("/home/${user}/.vnc/${user}:"[0-9]*)

	if [ ${#files[@]} -gt 0 ]; then
		rm -rf "${files[@]}"
	fi

	# check if systemd service is enabled
	if systemctl is-enabled vncserver.service >/dev/null 2>&1; then
		systemctl stop vncserver.service >/dev/null 2>&1
		systemctl disable --now vncserver.service >/dev/null 2>&1
	fi
}
