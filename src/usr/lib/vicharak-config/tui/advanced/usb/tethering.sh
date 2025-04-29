# shellcheck shell=bash

# shellcheck source=src/usr/lib/vicharak-config/tui/advanced/usb/gadget.sh
source "/usr/lib/vicharak-config/tui/advanced/usb/gadget.sh"

NETWORK_CONF="/etc/systemd/network/usb0.network"

__rndis_enable() {
	if [[ -L "$GADGET_DIR/configs/c.1/rndis.usb0" ]]; then
		echo "RNDIS is already enabled!"
		return
	fi

	mkdir -p "$GADGET_DIR/functions/rndis.usb0"
	ln -s "$GADGET_DIR/functions/rndis.usb0" "$GADGET_DIR/configs/c.1/"
	echo "RNDIS function enabled!"
}

__rndis_disable() {
	if [[ -L "$GADGET_DIR/configs/c.1/rndis.usb0" ]]; then
		rm -rf "$GADGET_DIR/configs/c.1/rndis.usb0"
	fi
}

__rndis_configure_network() {
	# Create network configuration if it doesn't exist
	if [[ ! -f "$NETWORK_CONF" ]]; then
		cat <<EOF > "$NETWORK_CONF"
[Match]
Name=usb0

[Network]
Address=10.42.0.1/24
DHCPServer=yes

[DHCPServer]
PoolOffset=100
PoolSize=50
EmitDNS=yes
DNS=8.8.8.8
EOF
		echo "Network configuration created: $NETWORK_CONF"
	fi

	systemctl restart systemd-networkd
	echo "Systemd-networkd restarted!"
}

__configure_iptables() {
	local usb_network="10.42.0.0/24"

	# Assuming Ethernet has "eth" or "en" prefix (e.g., eth0, enp3s0, end1)
	local iface
	iface=$(ip link show | awk -F: '/^[0-9]+: (eth|en)/ {print $2; exit}' | tr -d ' ')

	if [ -n "$iface" ]; then
		echo "Configuring NAT for usb0 (network ${usb_network}) via $iface..."
		iptables -t nat -A POSTROUTING -o "$iface" -s "$usb_network" -j MASQUERADE
		sysctl -w net.ipv4.ip_forward=1
	else
		echo "Error: No Ethernet interface found!"
		return 1
	fi
}

__advanced_usb_tethering_enable() {
	__usb_init_gadget
	__rndis_enable
	__usb_enable_gadget
	__rndis_configure_network
	__configure_iptables
	echo "USB tethering enabled!"
}

__advanced_usb_tethering_disable() {
	echo "Disabling USB tethering..."
	__rndis_disable

	# Stop systemd-networkd and remove network configuration
	if [[ -f "$NETWORK_CONF" ]]; then
		rm -f "$NETWORK_CONF"
		echo "Network configuration removed!"
	fi

	systemctl stop systemd-networkd
	echo "Systemd-networkd stopped!"
}

