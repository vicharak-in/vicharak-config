# shellcheck shell=bash

# shellcheck source=src/usr/lib/vicharak-config/mod/block_helpers.sh
source "/usr/lib/vicharak-config/mod/block_helpers.sh"
# shellcheck source=src/usr/lib/vicharak-config/mod/hwid.sh
source "/usr/lib/vicharak-config/mod/hwid.sh"

ALLOWED_VICHARAK_CONFIG_FUNC+=("update_hostname" "update_locale" "enable_service" "disable_service" "resize_root" "set_thermal_governor" "set_led_trigger" "show_progress" "record_histor" "extract_id")

bar_size=40
bar_char_done="#"
bar_char_todo="-"

update_bootloader() {
	local pid device
	pid="${1:-$(get_product_id)}"
	__assert_f "/usr/lib/u-boot/$pid/setup.sh"

	device="${2:-$(__get_block_dev)}"

	"/usr/lib/u-boot/$pid/setup.sh" update_bootloader "$device"
}

update_spinor() {
	local pid
	pid="${1:-$(get_product_id)}"
	__assert_f "/usr/lib/u-boot/$pid/setup.sh"

	"/usr/lib/u-boot/$pid/setup.sh" update_spinor
}

update_emmc_boot() {
	local pid device
	pid="${1:-$(get_product_id)}"
	__assert_f "/usr/lib/u-boot/$pid/setup.sh"

	for device in /dev/mmcblk*boot0; do
		"/usr/lib/u-boot/$pid/setup.sh" update_emmc_boot "$device"
	done
}

update_hostname() {
	__parameter_count_check 1 "$@"

	local hostname="$1"

	echo "$hostname" >"/etc/hostname"
	cat <<EOF >"/etc/hosts"
127.0.0.1 localhost
127.0.1.1 $hostname

# The following lines are desirable for IPv6 capable hosts
#::1     localhost ip6-localhost ip6-loopback
#fe00::0 ip6-localnet
#ff00::0 ip6-mcastprefix
#ff02::1 ip6-allnodes
#ff02::2 ip6-allrouters
EOF
}

update_locale() {
	__parameter_count_check 1 "$@"

	local locale="$1"
	echo "locales locales/default_environment_locale select $locale" | debconf-set-selections
	echo "locales locales/locales_to_be_generated multiselect $locale UTF-8" | debconf-set-selections
	rm "/etc/locale.gen"
	dpkg-reconfigure --frontend noninteractive locales
}

enable_service() {
	__parameter_count_check 1 "$@"

	local service="$1"
	systemctl enable --now "$service"
}

disable_service() {
	__parameter_count_check 1 "$@"

	local service="$1"
	systemctl disable --now "$service"
}

resize_root() {
	local root_dev filesystem
	root_dev="$(__get_root_dev)"
	filesystem="$(blkid -s TYPE -o value "$root_dev")"

	echo "Resizing root filesystem..."
	case "$filesystem" in
	ext4)
		resize2fs "$root_dev"
		;;
	btrfs)
		btrfs filesystem resize max /
		;;
	*)
		echo "Unknown filesystem." >&2
		return 1
		;;
	esac
}

set_thermal_governor() {
	__parameter_count_check 1 "$@"

	local new_policy="$1" i
	for i in /sys/class/thermal/thermal_zone*/policy; do
		echo "$new_policy" >"$i"
	done
}

VICHARAK_BUILD_LED_GPIO_ROOT_PATH="/sys/bus/platform/drivers/leds-gpio"

set_led_trigger() {
	__parameter_count_check 2 "$@"

	local led="$1" trigger="$2" node
	for node in "$VICHARAK_BUILD_LED_GPIO_ROOT_PATH"/*/leds/"$led"/trigger; do
		echo "$trigger" >"$node"
	done
}

show_progress() {
    local current="$1"
    local total="$2"

    # Prevent division by zero
    [ "$total" -le 0 ] && return

    # Clamp current to total
    if [ "$current" -gt "$total" ]; then
        current="$total"
    fi

    # Calculate percentage
    local percent=$(( 100 * current / total ))

    # Clamp percent (extra safety)
    if [ "$percent" -gt 100 ]; then
        percent=100
    fi

    # Calculate bar segments
    local done=$(( bar_size * percent / 100 ))
    local todo=$(( bar_size - done ))

    local done_sub_bar
    local todo_sub_bar

    done_sub_bar=$(printf "%${done}s" | tr " " "$bar_char_done")
    todo_sub_bar=$(printf "%${todo}s" | tr " " "$bar_char_todo")

    # Render bar
    printf "\rProgress : [%s%s] %3d%% (%d/%d)" \
        "$done_sub_bar" "$todo_sub_bar" "$percent" "$current" "$total"

    # Finish cleanly
    if [ "$current" -eq "$total" ]; then
        echo
    fi
}

record_history() {
    local id="$1"
    local status="$2"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "${id}|${status}|${ts}" >> "$HISTORY_FILE"
}

extract_id() {
    basename "$1"
}

generate_local_manifest() {
    (
        cd "$UPDATE_DIR" || exit 1
        sha256sum ./*.sh | sha256sum
    ) > "$LOCAL_MANIFEST"
}

compare_aggregate_manifest() {
    local remote_hash local_hash

    wget -q "$BASE_URL/manifest.sha256" -O "$REMOTE_MANIFEST" || return 0
    remote_hash="$(awk '{print $1}' "$REMOTE_MANIFEST")"

    [[ -f "$LOCAL_MANIFEST" ]] || return 0
    local_hash="$(awk '{print $1}' "$LOCAL_MANIFEST")"

    [[ "$remote_hash" == "$local_hash" ]] && return 1
    return 0
}

# ============================================================
# Update Engine
# ============================================================
__run_check_update_script() {

    set -euo pipefail

    mkdir -p "$UPDATE_DIR" "$STATE_DIR" "$LOG_DIR"

    if ! compare_aggregate_manifest; then
        msgbox "Update is not available."
        return 0
    fi

    if ! yesno "Update is available. Do you want to update system ?"; then
        return
    fi

    # --------------------------------------------------------
    # Download all scripts
    # --------------------------------------------------------
    rm -f "$UPDATE_DIR"/*.sh

    wget -q -r -np -nd -A "*.sh" "$BASE_URL/" -P "$UPDATE_DIR"
    chmod +x "$UPDATE_DIR"/*.sh

    # --------------------------------------------------------
    # Execute scripts
    # --------------------------------------------------------
    mapfile -t SCRIPTS < <(find "$UPDATE_DIR" -maxdepth 1 -name "*.sh" | sort)

    TOTAL=${#SCRIPTS[@]}
    COUNT=0

    for script in "${SCRIPTS[@]}"; do
        COUNT=$((COUNT + 1))
        ID="$(extract_id "$script")"

        if "$script"; then
            record_history "$ID" "OK"
            echo "[SUCCESS] | Date : $(date '+%Y-%m-%d %H:%M:%S') | $ID" >> "$LOG_FILE"
        else
            record_history "$ID" "FAILED"
            echo "[FAILED]  | Date : $(date '+%Y-%m-%d %H:%M:%S') | $ID" >> "$LOG_FILE"
        fi

        show_progress "$COUNT" "$TOTAL"
        sleep 0.3
    done

    generate_local_manifest
    cp "$REMOTE_MANIFEST" "$LOCAL_MANIFEST"
    msgbox "System is updated successfully"
}
