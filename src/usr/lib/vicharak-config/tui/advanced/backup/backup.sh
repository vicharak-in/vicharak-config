# shellcheck shell=bash

__backup_vicharak(){
	if yesno "The backup process will take some time. Do you wish to continue?"; then

		# Extract board name and convert to lowercase
		BOARD_NAME=$(awk '{print tolower($3)}' < /sys/firmware/devicetree/base/model)
		ROOTFS_PARTITION="/dev/$(lsblk -rno NAME /dev/"$SELECTED_BACKUP_SRC" | tail -n1)";

		# Set backup image filename depending on type of backup
		if (( IS_FULL_BACKUP == 0 )); then
			BACKUP_IMAGE="${BOARD_NAME}_rootfs_backup$(date +%Y%m%d_%H%M%S).tar.gz"
		else
			BACKUP_IMAGE="${BOARD_NAME}_full_backup$(date +%Y%m%d_%H%M%S).img"
		fi

		# Define mount points and paths
		ROOTFS_MOUNT_POINT="/mnt/${BOARD_NAME}_bckp_rootfs"
		BACKUP_DRIVE_MOUNT_POINT="/mnt/${BOARD_NAME}_bckp_drive"
		BACKUP_PARTITION="/dev/$SELECTED_PARTITION"
		BACKUP_DIR_NAME="vicharak_${BOARD_NAME}_backup"
		BACKUP_DIR="$BACKUP_DRIVE_MOUNT_POINT/$BACKUP_DIR_NAME"

		# Cleanup function
		_cleanup() {
			cd ~ 2>/dev/null || true
			umount "$ROOTFS_MOUNT_POINT" 2>/dev/null || true
			umount "$BACKUP_DRIVE_MOUNT_POINT" 2>/dev/null || true
			rmdir "$ROOTFS_MOUNT_POINT" 2>/dev/null || true
			rmdir "$BACKUP_DRIVE_MOUNT_POINT" 2>/dev/null || true
		}

		# Error handler
		# shellcheck disable=SC2317
		_on_error() {
			echo "[ ERROR ] Backup failed. Cleaning up..."
			_cleanup
			msgbox "[ ERROR ] Backup Failed!\n\nPlease check logs or terminal output for more information."
			exit
		}

		trap _on_error ERR
		trap _cleanup EXIT

		# Mount the backup target partition
		mkdir -p "$BACKUP_DRIVE_MOUNT_POINT"
		mount "$BACKUP_PARTITION" "$BACKUP_DRIVE_MOUNT_POINT" || {
			echo "Failed to mount backup partition"
			exit 1
		}

		# Create backup directory inside the drive and cd there
		mkdir -p "$BACKUP_DIR"
		cd "$BACKUP_DIR" || exit 1

		# Mount rootfs partition
		mkdir -p "$ROOTFS_MOUNT_POINT"
		mount "$ROOTFS_PARTITION" "$ROOTFS_MOUNT_POINT" || {
			echo "Failed to mount rootfs partition"
			exit 1
		}

		if [[ $IS_FULL_BACKUP == 0 ]]; then
			tar --create --gzip --verbose --preserve-permissions --numeric-owner --same-owner --xattrs --acls --sparse --one-file-system --file="$BACKUP_IMAGE" -C "$ROOTFS_MOUNT_POINT" .

			# Verify tarball integrity
			gzip -t "$BACKUP_IMAGE" || {
				echo "Backup integrity test failed."
				exit 1
			}
			sync
		else
			# Full image backup using external helper script
			/usr/lib/vicharak-config/tui/advanced/backup/vicharak-backup.sh -u -m "$ROOTFS_MOUNT_POINT" -o "$BACKUP_IMAGE" || {
				echo "Full Backup Failed."
				exit 1
			}
			sync
		fi

		trap - ERR
		trap - EXIT
		_cleanup

		MOUNT_POINT=$(lsblk -o MOUNTPOINT -nr "/dev/$SELECTED_PARTITION" | grep "/media" | head -n 1)
		if [[ -n "$MOUNT_POINT" ]]; then
			msgbox "[ OK ] Backup Complete!

Backup file created at:
$MOUNT_POINT/$BACKUP_DIR_NAME/$BACKUP_IMAGE"

		else
			msgbox "[ OK ] Backup Complete!

Backup file created in partition: /dev/$SELECTED_PARTITION
Path inside the partition:
$BACKUP_DIR_NAME/$BACKUP_IMAGE

Note: Partition is not currently mounted on its own.
You can mount it manually to verify."
		fi

		return
	fi
}

__show_partitions(){
	menu_init

	# List all partitions of selected drive
	available_partitions=$(lsblk -rno NAME,SIZE,TYPE | grep "$SELECTED_DRIVE" | grep part)
	has_valid_partition=0

	while IFS= read -r line; do
		part=$(echo "$line" | awk '{print $1}')
		_size=$(echo "$line" | awk '{print $2}')
		_type=$(echo "$line" | awk '{print $NF}')

		if [[ "$_size" == *G ]]; then
			# Create wrapper for menu (dynamic function)
			wrapper="__select_drive_wrapper_${part}"
			eval "
			$wrapper() {
				SELECTED_PARTITION=\"$part\"
				__backup_vicharak
			}"

			# Add menu entry
			menu_add "$wrapper" "/dev/$part   $_size   $_type"
			has_valid_partition=1
		fi
	done <<< "$available_partitions"

	if [[ $has_valid_partition -eq 0 ]]; then
		msgbox "No suitable partitions found in selected disk"
		return
	fi

	menu_show "Available partitions for selected disk:"
}

__show_drives() {
	menu_init

	# List block devices with size/model/type
	available_drives=$(lsblk -rndo NAME,SIZE,MODEL,TYPE)
	has_valid_drive=0

	while IFS= read -r line; do
		drive=$(echo "$line" | awk '{print $1}')
		type=$(echo "$line" | awk '{print $NF}')
		size=$(echo "$line" | awk '{print $2}')
		# Skip system devices (mmcblk0, zram) and only allow "G" sizes
		if [[ "$drive" != mmcblk0* && "$drive" != zram* && "$size" == *G ]]; then
			model=$(echo "$line" | cut -d' ' -f3- | rev | cut -d' ' -f2- | rev)

			# Create wrapper function for each drive
			wrapper="__select_drive_wrapper_${drive}"
			eval "
			$wrapper() {
				SELECTED_DRIVE=\"$drive\"
				__show_partitions
			}"

			# Add to menu
			menu_add "$wrapper" "/dev/$drive   $size   $model   $type"
			has_valid_drive=1
		fi
	done <<< "$available_drives"

	if [[ $has_valid_drive -eq 0 ]]; then
		msgbox "No suitable drives found for backup"
		return
	fi

	menu_show "Select the drive where the backup should be stored: "
}

__select_backup_src() {
	menu_init

	BACKUP_SRC=$(lsblk -rno NAME,MOUNTPOINT,SIZE | awk '$2=="/" && $3 ~ /G/ {print $1}' | sed -E 's/p?[0-9]+$//')
	available_src_drives=$(lsblk -rndo NAME,SIZE,MODEL,TYPE)
	has_valid_src_drive=0

	while IFS= read -r line; do
		drive=$(echo "$line" | awk '{print $1}')
		type=$(echo "$line" | awk '{print $NF}')
		size=$(echo "$line" | awk '{print $2}')
		# Skip system devices (mmcblk0, zram) and only allow "G" sizes
		if [[ "$drive" != "$BACKUP_SRC"* && "$drive" != zram* && "$size" == *G ]]; then
			model=$(echo "$line" | cut -d' ' -f3- | rev | cut -d' ' -f2- | rev)

			# Create wrapper function for each drive
			wrapper="__select_src_drive_wrapper_${drive}"
			eval "
			$wrapper() {
				SELECTED_BACKUP_SRC=\"$drive\"
				__select_backup_type
			}"

			# Add to menu
			menu_add "$wrapper" "/dev/$drive   $size   $model   $type"
			has_valid_src_drive=1
		fi
	done <<< "$available_src_drives"

	if [[ $has_valid_src_drive -eq 0 ]]; then
		msgbox "No suitable drives found for backup"
		return
	fi

	menu_show "Select the drive which has the system to be backed up: "
}

full_backup_wrapper() {
	IS_FULL_BACKUP=1
	# Inform user about recommended kernel
	if ! msgbox "We recommend to use Vicharak 6.1 kernel and latest Ubuntu 24.04 Noble Numbat.
Use these commands to install latest kernel and headers.

sudo apt update
sudo apt reinstall linux-image-6.1.75-axon linux-headers-6.1.75-axon
"; then
		return
	fi
	__show_drives
}

rootfs_backup_wrapper() {
	IS_FULL_BACKUP=0
	__show_drives
}

__select_backup_type() {
	menu_init
	menu_add full_backup_wrapper "Full Backup (Creates a flashable image)"
	menu_add rootfs_backup_wrapper "Rootfs Backup (Only copies root filesystem)"
	menu_show "Available Backup Options:"
}

__advanced_backup() {
	SELECTED_DRIVE=""
	SELECTED_PARTITION=""
	SELECTED_BACKUP_SRC=""
	IS_FULL_BACKUP=0

	__select_backup_src
}
