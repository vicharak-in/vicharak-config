# shellcheck shell=bash
# shellcheck disable=SC2119

# shellcheck source=src/usr/lib/vicharak-config/cli/ssh.sh
source "/usr/lib/vicharak-config/cli/ssh.sh"

__advanced_ssh_uninstall() {
	if yesno "Are you sure to uninstall SSH service?"; then
		uninstall_ssh
		msgbox "Uninstall SSH success."
	fi
}

__advanced_ssh_install() {
	if yesno "Are you sure to install SSH service?"; then
		install_ssh
	fi
}

__advanced_ssh_enable() {
	if yesno "Would you like the SSH server to be enabled?
Caution: Default and weak passwords are a security risk when SSH is enabled!"; then
		if enable_ssh; then
			msgbox "Enable SSH success."
		else
			msgbox "Enable SSH failure."
		fi
	fi
}

__advanced_ssh_disable() {
	if yesno "Would you like the SSH server to be disabled?"; then
		if disable_ssh; then
			msgbox "Disable SSH success."
		else
			msgbox "Disable SSH failure."
		fi
	fi
}

__advanced_ssh() {
	menu_init

	if __is_installed openssh-server; then
		menu_add __advanced_ssh_uninstall "Uninstall SSH"
	else
		menu_add __advanced_ssh_install "Install SSH"
	fi

	local status
	status=$(systemctl status ssh | grep Loaded | awk '{print $4}')
	if [[ "$status" == "enabled;" ]]; then
		menu_add __advanced_ssh_disable "Disable SSH"
	elif [[ "$status" == "disabled;" ]]; then
		menu_add __advanced_ssh_enable "Enable SSH"
	fi

	menu_show "Please select an option below:"
}
