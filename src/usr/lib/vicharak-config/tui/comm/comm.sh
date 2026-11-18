# shellcheck shell=bash

__comm_network() {
	nmtui
}

__comm_bluetooth() {
	msgbox "Configure Bluetooth"
}

# Check if the current board is Vicharak RK3588 Axon
__is_axon_board() {
	local compatible_file="/sys/firmware/devicetree/base/compatible"
	[[ ! -f "$compatible_file" ]] && compatible_file="/proc/device-tree/compatible"

	if [[ -f "$compatible_file" ]]; then
		tr '\0' '\n' < "$compatible_file" | grep -qFx "vicharak,rk3588-axon"
		return $?
	fi
	return 1
}

__create_hotspot() {
    local default_ssid="VicharakHotspot"
    local default_pass="Vicharak123"
    local default_ip="10.42.0.1/24"

    # Fetch existing hotspot settings
    if nmcli connection show id "Hotspot" &>/dev/null; then
        local existing_ssid existing_pass existing_ip

        existing_ssid=$(nmcli -g 802-11-wireless.ssid connection show id "Hotspot" 2>/dev/null)
        existing_pass=$(nmcli -s -g 802-11-wireless-security.psk connection show id "Hotspot" 2>/dev/null)
        existing_ip=$(nmcli -g ipv4.addresses connection show id "Hotspot" 2>/dev/null)

        [ -n "$existing_ssid" ] && default_ssid="$existing_ssid"
        [ -n "$existing_pass" ] && default_pass="$existing_pass"
        [ -n "$existing_ip" ] && default_ip="$existing_ip"
    fi

    # SSID input
    local custom_ssid
    custom_ssid=$(inputbox "Enter your desired Hotspot Name (SSID):" "$default_ssid")
    [ -z "$custom_ssid" ] && return 1

    # Password input
    local custom_pass
    custom_pass=$(inputbox "Enter a Wi-Fi Password (minimum 8 characters):" "$default_pass")
    [ -z "$custom_pass" ] && return 1

    if [ "${#custom_pass}" -lt 8 ]; then
        msgbox "Error: Password must be at least 8 characters long."
        return 1
    fi

    # Hotspot IP input
    local custom_ip
    custom_ip=$(inputbox \
        "Enter Hotspot IP with Subnet (e.g. 10.42.0.1/24):" \
        "$default_ip")

    [ -z "$custom_ip" ] && return 1

    # Append /24 automatically if subnet is missing
    if [[ "$custom_ip" != */* ]]; then
        custom_ip="${custom_ip}/24"
    fi

    # Validate IPv4 CIDR format
    if ! [[ "$custom_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$ ]]; then
        msgbox "Error: Invalid IP format '$custom_ip'. Use format like 10.42.0.1/24."
        return 1
    fi

    # Validate IPv4 octets (0-255)
    local ip_address octet
    ip_address="${custom_ip%/*}"

    IFS='.' read -r -a octets <<< "$ip_address"

    for octet in "${octets[@]}"; do
        if (( 10#$octet > 255 )); then
            msgbox "Error: Invalid IPv4 address '$custom_ip'. Each octet must be between 0 and 255."
            return 1
        fi
    done

    # Detect Wi-Fi interface
    local wifi_iface
    wifi_iface=$(nmcli -t -f DEVICE,TYPE device |
        awk -F: '$2 == "wifi" {print $1; exit}')

    if [ -z "$wifi_iface" ]; then
        msgbox "Error: No Wi-Fi interface detected."
        return 1
    fi

    # Delete old profile
    if nmcli connection show id "Hotspot" &>/dev/null; then
        if ! nmcli connection delete id "Hotspot"; then
            msgbox "Error: Could not delete existing Hotspot."
            return 1
        fi
    fi

    # Create new hotspot
    if nmcli device wifi hotspot \
        ifname "$wifi_iface" \
        con-name Hotspot \
        ssid "$custom_ssid" \
        password "$custom_pass"; then

        # Configure hotspot IPv4 settings
        local err_out
        if ! err_out=$(nmcli connection modify id "Hotspot" \
            ipv4.method shared \
            ipv4.addresses "$custom_ip" 2>&1); then

            nmcli connection delete id "Hotspot" &>/dev/null
            msgbox "Error: Failed to configure Hotspot IP.\n\nDetails: $err_out"
            return 1
        fi

        # Keep hotspot profile saved but inactive
        nmcli connection down id "Hotspot" &>/dev/null

        msgbox "Success! Hotspot '$custom_ssid' created with IP '$custom_ip'."
        return 0

    else
        msgbox "Error: Failed to create Hotspot profile.\n\nCheck NetworkManager logs and Wi-Fi AP support."
        return 1
    fi
}

__comm_hotspot_wizard() {

    # Allow Hotspot Manager only on Vicharak Axon
    if ! __is_axon_board; then
        msgbox "Hotspot Manager is only supported on Vicharak Axon."
        return
    fi

    # Fetch saved SSID, Password, and IP
    local hotspot_info="Saved Hotspot -> SSID: No hotspot created | Password: No hotspot created | IP: N/A"

    if nmcli connection show id "Hotspot" &>/dev/null; then
        local cur_ssid cur_pass cur_ip

        cur_ssid=$(nmcli -g 802-11-wireless.ssid connection show id "Hotspot" 2>/dev/null)
        cur_pass=$(nmcli -s -g 802-11-wireless-security.psk connection show id "Hotspot" 2>/dev/null)
        cur_ip=$(nmcli -g ipv4.addresses connection show id "Hotspot" 2>/dev/null)

        hotspot_info="Saved Hotspot -> SSID: ${cur_ssid:-N/A} | Password: ${cur_pass:-N/A} | IP: ${cur_ip:-10.42.0.1/24}"
    fi

    # Determine currently active mode
    local now_state="OFF" boot_state="OFF" button_state="OFF" off_state="ON"

    if systemctl is-enabled --quiet hotspot-trigger.service 2>/dev/null; then
        button_state="ON"
        off_state="OFF"

    elif [ "$(nmcli -g connection.autoconnect connection show id "Hotspot" 2>/dev/null)" = "yes" ]; then
        boot_state="ON"
        off_state="OFF"

    elif nmcli -t -f NAME connection show --active 2>/dev/null | grep -qx "Hotspot"; then
        now_state="ON"
        off_state="OFF"
    fi

    # Display hotspot management menu
    local choice rc

    choice=$(whiptail --title "Advanced Hotspot Manager" --notags --radiolist \
        "${hotspot_info}\n\nSpace = select one mode, Enter = apply." 20 82 5 \
        "NOW"    "Immediate Activation" "$now_state" \
        "BOOT"   "On Boot-Time" "$boot_state" \
        "BUTTON" "Hardware Triggered (using recovery button)" "$button_state" \
        "OFF"    "Disable All Hotspot Modes" "$off_state" \
        "CREATE" "Create / Recreate Hotspot (SSID, Password & IP)" "OFF" \
        3>&1 1>&2 2>&3)

    rc=$?

    # Cancel / Esc: change nothing
    [ "$rc" -ne 0 ] && return

    # Handle CREATE option
    if [ "$choice" = "CREATE" ]; then
        __create_hotspot
        return
    fi

    # Block activation if Hotspot profile does not exist
    if [ "$choice" != "OFF" ] && ! nmcli connection show id "Hotspot" &>/dev/null; then
        msgbox "No hotspot created!\n\nPlease create a Hotspot first by selecting 'Create / Recreate Hotspot (SSID, Password & IP)'."
        return
    fi

    # Reset existing hotspot modes
    nmcli connection modify id "Hotspot" connection.autoconnect no &>/dev/null

    if systemctl is-active --quiet hotspot-trigger.service 2>/dev/null || \
       systemctl is-enabled --quiet hotspot-trigger.service 2>/dev/null; then
        systemctl disable --now --no-block hotspot-trigger.service &>/dev/null
    fi

    local summary=""

    case "$choice" in
        NOW)
            nmcli connection up id "Hotspot" &>/dev/null &
            summary="- Mode set to: Immediate Activation (ON)"
            ;;

        BOOT)
            nmcli connection modify id "Hotspot" connection.autoconnect yes &>/dev/null
            nmcli connection down id "Hotspot" &>/dev/null &
            summary="- Mode set to: On Boot-Time (ON)"
            ;;

        BUTTON)
            systemctl enable --now --no-block hotspot-trigger.service &>/dev/null
            nmcli connection down id "Hotspot" &>/dev/null &
            summary="- Mode set to: Hardware Triggered (ON)"
            ;;

        OFF)
            nmcli connection down id "Hotspot" &>/dev/null &
            summary="- All Hotspot modes turned OFF"
            ;;
    esac

    msgbox "Hotspot settings applied:\n\n${summary}"
}

__comm() {
    menu_init

    menu_add __comm_network "Network"

    if __is_axon_board; then
        menu_add __comm_hotspot_wizard "Hotspot Manager"
    fi

    if $DEBUG; then
        menu_add __comm_bluetooth "Bluetooth"
    fi

    menu_show "Manage Connectivity"
}
