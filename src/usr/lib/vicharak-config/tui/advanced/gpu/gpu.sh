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

__advanced_gpu_enable_opengl() {
	if yesno "Are you sure to enable OpenGL support for Rockchip Mali gpu?"; then
		if enable_gpu_opengl; then
			msgbox "Enabled OpenGL support for Rockchip Mali gpu.\n\nUse 'gl4es' prefix to run OpenGL applications."
		else
			msgbox "Failed to enable OpenGL support for Rockchip Mali gpu."
		fi
	fi
}

__advanced_gpu_disable_opengl() {
	if yesno "Are you sure to disable OpenGL support for Rockchip Mali gpu?"; then
		if disable_gpu_opengl; then
			msgbox "Disabled OpenGL support for Rockchip Mali gpu."
		else
			msgbox "Failed to disable OpenGL support for Rockchip Mali gpu."
		fi
	fi
}

__advanced_gpu() {
	menu_init

	if __is_installed libmali*; then
		menu_add __advanced_gpu_uninstall "Uninstall Rockchip Mali gpu"
	else
		menu_add __advanced_gpu_install "Install Rockchip Mali gpu"
	fi

	if [ -f /usr/bin/gl4es ]; then
		menu_add __advanced_gpu_disable_opengl "Disable OpenGL support for Rockchip Mali gpu"
	else
		menu_add __advanced_gpu_enable_opengl "Enable OpenGL support for Rockchip Mali gpu"
	fi

	menu_show "Please select an option below:"
}
