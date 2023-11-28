# shellcheck shell=bash
# shellcheck disable=SC2119

# shellcheck source=src/usr/lib/vicharak-config/cli/vncserver.sh
source "/usr/lib/vicharak-config/cli/vncserver.sh"

__advanced_enable_vncserver() {
	if yesno "Are you sure to enable VNC server?"; then
		if enable_vncserver; then
			local user
			local available_ports
			user=$(logname)
			available_ports=$(ls "/home/${user}/.vnc/${user}:"[0-9]*.log)
			for port in ${available_ports}; do
				msgbox "Successfully enabled VNC server at localhost:$(grep -oP "TCP port \K\d+" "${port}")."
			done
		else
			msgbox "Failed to enable VNC server."
		fi
	fi
}

__advanced_install_vncserver() {
	if yesno "Are you sure to install server?"; then
		if ! install_vncserver; then
			msgbox "Unable to install VNC server."
			return
		else
			local user
			user=$(logname)
			# Check for old password
			if [[ -f "/home/${user}/.vnc/passwd" ]]; then
				msgbox "Found old password. Remove it before configuring VNC server."
				rm -f "/home/${user}/.vnc/passwd"
			fi
			if [[ -f "/root/.vnc/passwd" ]]; then
				msgbox "Found old password in root. Remove it before configuring VNC server."
				rm -f "/root/.vnc/passwd"
			fi

			vncpasswd

			if [ ! -d "/home/${user}/.vnc" ]; then
				mkdir -p "/home/${user}/.vnc"
			fi
			chown "${user}:${user}" "/home/${user}/.vnc"

			sudo cp -pdR "/root/.vnc/passwd" "/home/${user}/.vnc/passwd"
			chown "${user}:${user}" "/home/${user}/.vnc/passwd"

			if [[ -f "/home/${user}/.vnc/xstartup" ]]; then
				rm -f "/home/${user}/.vnc/xstartup"
			fi
			cat <<EOF >"/home/${user}/.vnc/xstartup"
#!/bin/bash

# Change "gnome" to "xfce" for a xfce desktop, or "lxde" for lxde desktop
# or "" for a generic desktop
MODE="lxde"
export XKL_XMODMAP_DISABLE=1
export LD_LIBRARY_PATH="/usr/lib/aarch64-linux-gnu:\${LD_LIBRARY_PATH}"

if [ -e "\$HOME/.Xresources" ]; then
	xrdb "\$HOME/.Xresources"
fi
autocutsel -fork

if [ "\$MODE" = "lxde" ]; then
	if command -v startlxde >/dev/null 2>&1; then
		startlxde &
	else
		MODE=""
	fi
elif [ "\$MODE" = "xfce" ]; then
	if command -v startxfce4 >/dev/null 2>&1; then
		startxfce4 &
	else
		MODE=""
	fi
elif [ "\$MODE" = "gnome" ]; then
	if command -v gnome-session >/dev/null 2>&1; then
		gnome-session &
	else
		MODE="xfce"
	fi
else
	MODE=""
fi

if [ -z "\$MODE" ]; then
	xsetroot -solid grey
	x-terminal-emulator -geometry 80x24+10+10 -ls -title "\$VNCDESKTOP Desktop" &
	x-window-manager &
fi
EOF

			chown "${user}:${user}" "/home/${user}/.vnc/xstartup"
			chmod +x "/home/${user}/.vnc/xstartup"

			msgbox "Successfully installed VNC server.\nYou can enable it from menu now."
		fi
	fi
}

__advanced_disable_vncserver() {
	if yesno "Are you sure to disable VNC server?"; then
		if disable_vncserver; then
			msgbox "Successfully disabled VNC server."
		else
			msgbox "Failed to disable VNC server."
		fi
	fi
}

__advanced_remove_vncserver() {
	if yesno "Are you sure to uninstall VNC server?"; then
		if ! uninstall_vncserver; then
			msgbox "Unable to uninstall VNC server."
		else
			msgbox "Successfully uninstalled VNC server."
		fi
	fi
}

__advanced_vncserver() {
	menu_init
	if __is_installed tightvncserver; then
		menu_add __advanced_remove_vncserver "Uninstall VNC server"

		if [[ "$(systemctl is-enabled vncserver.service)" == "enabled" ]]; then
			menu_add __advanced_disable_vncserver "Disable VNC server"
		else
			menu_add __advanced_enable_vncserver "Enable VNC server"
		fi
	else
		menu_add __advanced_install_vncserver "Install VNC server"
	fi

	menu_show "Please select an option below:"
}
