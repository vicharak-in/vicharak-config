# shellcheck shell=bash

__task_gpu_uninstall() {
	echo "Uninstalling Mali gpu..." 2>&1 | tee -a "test"
	if yesno "Are you sure to uninstall Mali gpu?"; then
		if uninstall_gpu; then
			msgbox "Uninstall Mali gpu success."
		else
			msgbox "Uninstall Mali gpu failure."
		fi
	fi
}

__task_gpu_install() {
	echo "Installing Mali gpu..." 2>&1 | tee -a "test"
	if yesno "Are you sure to install Mali gpu?"; then
		install_gpu
	fi
}

__task_gpu_enable() {
	if yesno "Are you sure to enable Mali gpu?"; then
		if enable_gpu; then
			msgbox "Enable Mali gpu success."
		else
			msgbox "Enable Mali gpu failure."
		fi
	fi
}

__task_gpu_disable() {
	if yesno "Are you sure to enable Mali gpu?"; then
		if disable_gpu; then
			msgbox "Disable Mali gpu success."
		else
			msgbox "Disable Mali gpu failure."
		fi
	fi
}

__task_gpu() {
	menu_init

	if apt list --installed | grep -q "libmali"; then
		menu_add __task_gpu_uninstall "Uninstall Mali gpu"
	else
		menu_add __task_gpu_install "Install Mali gpu"
	fi

	if grep -q "gl4es" /etc/environment; then
		menu_add __task_gpu_disable "Disable Mali gpu"
	else
		menu_add __task_gpu_enable "Enable Mali gpu"
	fi

	menu_show "Please select an option below:"
}
