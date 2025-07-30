# shellcheck shell=bash

__advanced_gpu_uninstall() {
	echo "Uninstalling Rockchip Mali gpu..." 2>&1 | tee -a "test"
	if yesno "Are you sure to uninstall Rockchip Mali gpu?"; then
		if uninstall_gpu; then
			msgbox "Uninstall Rockchip Mali gpu success."
		else
			msgbox "Uninstall Rockchip Mali gpu failure."
		fi
	fi
}

__advanced_gpu_install() {
	echo "Installing Mali gpu..." 2>&1 | tee -a "test"
	if yesno "Are you sure to install Rockchip Mali gpu library?"; then
		install_gpu
	fi
}

__advanced_gpu() {
	menu_init

	if __is_installed libmali*; then
		menu_add __advanced_gpu_uninstall "Uninstall Rockchip Mali gpu"
	else
		menu_add __advanced_gpu_install "Install Rockchip Mali gpu"
	fi

	menu_show "Please select an option below:"
}
