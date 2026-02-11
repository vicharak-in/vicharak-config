# shellcheck shell=bash

# shellcheck source=src/usr/lib/vicharak-config/cli/system.sh
source "/usr/lib/vicharak-config/cli/system.sh"

# ============================================================
# Configuration
# ============================================================
export STATE_FILE
export LOCK_FILE
SCRIPTS=()
BASE_URL="https://downloads.vicharak.in/vicharak-application/vicharak-update/update"

ROOT="/opt/vicharak-update"
UPDATE_DIR="$ROOT/update"
STATE_DIR="$ROOT/state"
LOG_DIR="$ROOT/logs"

STATE_FILE="$STATE_DIR/update.state"
HISTORY_FILE="$STATE_DIR/update.history"
LOCAL_MANIFEST="$STATE_DIR/local.sha256"
REMOTE_MANIFEST="$STATE_DIR/remote.sha256"

LOG_FILE="$LOG_DIR/update.log"
LOCK_FILE="/var/lock/vicharak-update.lock"

bar_size=40
bar_char_done="#"
bar_char_todo="-"

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

__system_system_update() {
    menu_init
    menu_add __run_check_update_script "Check & Apply Updates"
    menu_show "Vicharak Update Menu"
}

__system_update_bootloader() {
	if ! yesno "Updating bootloader is not necessary in most cases.
Incorrect bootloader can make system unbootable.

Are you sure you want to update the bootloader?"; then
		return
	fi

	radiolist_init

	local pid
	pid="$(get_product_id)"
	for i in /usr/lib/u-boot/"$pid"*; do
		radiolist_add "${i##/usr/lib/u-boot/}" "OFF"
	done
	radiolist_emptymsg "No compatible bootloader is available."

	if ! radiolist_show "Please select the bootloader to be installed:" || ((${#VICHARAK_CONFIG_RADIOLIST_STATE_NEW[@]} == 0)); then
		return
	fi

	if update_bootloader "$(radiolist_getitem "${VICHARAK_CONFIG_RADIOLIST_STATE_NEW[0]}")"; then
		msgbox "The bootloader has been updated successfully."
	else
		ret=$?
		case $ret in
		100)
			msgbox "The selected bootloader does not support installing on the boot media."
			;;
		*)
			msgbox "The updating process has failed. System might be broken!"
			;;
		esac
	fi
}

__system_update_spinor() {
	if ! yesno "Updating bootloader is not necessary in most cases.
Incorrect bootloader can make system unbootable.

In addition, SPI bootloader is stored on non-removable storage, and it is harder
to recover from a failed state.

You should only use this option when you are confident to recover a corrupted
SPI bootloader, or have flashed on-board SPI flash manually before.

Are you sure you want to update the bootloader?"; then
		return
	fi

	radiolist_init

	local pid ret
	pid="$(get_product_id)"
	for i in /usr/lib/u-boot/"$pid"*; do
		radiolist_add "${i##/usr/lib/u-boot/}" "OFF"
	done
	radiolist_emptymsg "No compatible bootloader is available."

	if ! radiolist_show "Please select the bootloader to be installed:" || ((${#VICHARAK_CONFIG_RADIOLIST_STATE_NEW[@]} == 0)); then
		return
	fi

	if update_spinor "$(radiolist_getitem "${VICHARAK_CONFIG_RADIOLIST_STATE_NEW[0]}")"; then
		msgbox "The bootloader has been updated successfully."
	else
		ret=$?
		case $ret in
		100)
			msgbox "The selected bootloader does not support SPI boot."
			;;
		*)
			msgbox "The updating process has failed. System might be broken!"
			;;
		esac
	fi
}

__system_update_emmc_boot() {
	if ! yesno "Updating bootloader is not necessary in most cases.
Incorrect bootloader can make system unbootable.

In addition, eMMC Boot partition could be on the non-removable storage, and it is
harder to recover from a failed state.

You should only use this option when you are confident to recover a corrupted
eMMC Boot partition, or have flashed on-board eMMC Boot partition manually before.

Are you sure you want to update the bootloader?"; then
		return
	fi

	radiolist_init

	local pid
	pid="$(get_product_id)"
	for i in /usr/lib/u-boot/"$pid"*; do
		radiolist_add "${i##/usr/lib/u-boot/}" "OFF"
	done
	radiolist_emptymsg "No compatible bootloader is available."

	if ! radiolist_show "Please select the bootloader to be installed:" || ((${#VICHARAK_CONFIG_RADIOLIST_STATE_NEW[@]} == 0)); then
		return
	fi

	if update_emmc_boot "$(radiolist_getitem "${VICHARAK_CONFIG_RADIOLIST_STATE_NEW[0]}")"; then
		msgbox "The bootloader has been updated successfully."
	else
		ret=$?
		case $ret in
		100)
			msgbox "The selected bootloader does not support booting from eMMC Boot partition."
			;;
		*)
			msgbox "The updating process has failed. System might be broken!"
			;;
		esac
	fi
}

__system() {
	menu_init
    menu_add __system_system_update "Vicharak Update"
	# menu_add __system_update_bootloader "Update Bootloader"
	# menu_add __system_update_spinor "Update SPI Bootloader"
	# menu_add __system_update_emmc_boot "Update eMMC U-Boot partition"
	menu_show "System Maintenance"
}
