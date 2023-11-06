# shellcheck shell=bash

install_vncserver() {
	__parameter_count_check 0 "$@"
	apt-get install x11vnc
}

uninstall_vncserver() {
	__parameter_count_check 0 "$@"
	apt-get remove x11vnc
}

enable_vncserver() {
	__parameter_count_check 0 "$@"

	# check if systemd service is enabled
	if systemctl is-enabled vncserver.service; then
		systemctl start vncserver.service >/dev/null 2>&1
	else
		systemctl enable --now vncserver.service >/dev/null 2>&1
	fi
}

disable_vncserver() {
	__parameter_count_check 0 "$@"

	# check if systemd service is enabled
	if systemctl is-enabled vncserver.service; then
		systemctl stop vncserver.service >/dev/null 2>&1
		systemctl disable --now vncserver.service >/dev/null 2>&1
	fi
}
