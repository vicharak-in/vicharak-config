# shellcheck shell=bash
# shellcheck disable=SC2119

# shellcheck source=src/usr/lib/vicharak-config/cli/vncserver.sh
source "/usr/lib/vicharak-config/cli/vncserver.sh"

__advanced_enable_vncserver() {
 if yesno "Are you sure to enable x11vnc server?"; then
        if systemctl start vnc.service; then
            # Wait for x11vnc to start and retrieve the port from logs
            sleep 2  # Wait a moment for the service to initialize

            local x11vnc_port
            x11vnc_port=$(journalctl -u vnc.service --since "2 minutes ago" | grep -oP "Listening for VNC connections on TCP port \K\d+" | tail -n 1)

            if [[ -n "${x11vnc_port}" ]]; then
                msgbox "Successfully active x11vnc server at localhost:${x11vnc_port}."
            else
                msgbox "x11vnc is running, but the port number could not be found in the logs."
            fi
        else
            msgbox "Failed to enable x11vnc server."
        fi
    fi
}

__advanced_install_vncserver() {
    if yesno "Are you sure to install x11vnc server?"; then
        if ! install_vncserver; then
            msgbox "Unable to install x11vnc server."
            return
        else
            local user
            user=$(logname)
            
            # Check for old password file
            if [[ -f "/etc/x11vnc.passwd" ]]; then
                msgbox "Found old x11vnc password. Remove it before configuring x11vnc server."
                rm -f "/etc/x11vnc.passwd"
            fi
            
            # Set new password
            x11vnc -storepasswd "12345" /etc/x11vnc.passwd
            chmod 600 /etc/x11vnc.passwd
            
            # Create a systemd service for x11vnc
            cat <<EOF >/etc/systemd/system/vnc.service
[Unit]
Description=VNC Server
After=multi-user.target network.target

[Service]
Restart=always
ExecStart=/usr/bin/x11vnc -auth guess -forever -loop -noxdamage -repeat -rfbauth /etc/x11vnc.passwd -rfbport 5900 -shared

[Install]
WantedBy=multi-user.target
EOF

            # Reload systemd, enable and start the service
            systemctl daemon-reload
            systemctl enable vnc.service
            systemctl start vnc.service

            msgbox "Successfully installed x11vnc server.\nYou can control it via systemd now."
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
	if __is_installed x11vnc; then
		menu_add __advanced_remove_vncserver "Uninstall VNC server"

		if [[ "$(systemctl is-active vnc.service)" == "active" ]]; then
			menu_add __advanced_disable_vncserver "Disable VNC server"
		else
			menu_add __advanced_enable_vncserver "Enable VNC server"
		fi
	else
		menu_add __advanced_install_vncserver "Install VNC server"
	fi

	menu_show "Please select an option below:"
}
