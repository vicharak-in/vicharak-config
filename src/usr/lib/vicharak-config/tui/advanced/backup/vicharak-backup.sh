#!/bin/bash
LANGUAGE=en
set -e
# shellcheck disable=SC2086
SCRIPT_NAME=$(basename $0)
ROOT_MOUNT=$(mktemp -d)

# shellcheck disable=SC2034
DEVICE=/dev/$(mount | sed -n 's|^/dev/\(.*\) on / .*|\1|p' | cut -b 1-7)

# shellcheck disable=SC2006
model=$(uname -n)

MOUNT_POINT=/
GROW_SCRIPT=/usr/local/bin/growpart-by-backup.sh
GROW_SERVER_NAME=growpart-by-backup
GROW_SERVER=/etc/systemd/system/$GROW_SERVER_NAME.service

check_root() {
        # shellcheck disable=SC2046
        if [ $(id -u) != 0 ]; then
                echo -e "${SCRIPT_NAME} needs to be run as root.\n"
                exit 1
        fi
}

get_option() {
        exclude=""
        # shellcheck disable=SC2034
        label=rootfs
        OLD_OPTIND=$OPTIND
        while getopts "o:e:uhm:" flag; do
                # shellcheck disable=SC2220
                case $flag in
                        o)
                                output="$OPTARG"
                                ;;
                        e)
                                exclude="${exclude} --exclude ${OPTARG}"
                                ;;
                        u)
                                $OPTARG
                                unattended="1"
                                ;;
                        h)
                                $OPTARG
                                print_help="1"
                                ;;
                        m)
                                MOUNT_POINT="$OPTARG"
                                ;;
                esac
        done
        OPTIND=$OLD_OPTIND
}

confirm() {
        if [ "$unattended" == "1" ]; then
                return 0
        fi
        printf "\n%s [y/N] " "$1"
        # shellcheck disable=SC2162
        read resp
        if [ "$resp" == "Y" ] || [ "$resp" == "y" ] || [ "$resp" == "yes" ]; then
                return 0
        fi
        if [ "$2" == "abort" ]; then
                echo -e "Abort.\n"
                exit 0
        fi
        if [ "$2" == "clean" ]; then
                rm "$3"
                echo -e "Abort.\n"
                exit 0
        fi
        return 1
}

check_part() {
        echo Checking disk...
        # shellcheck disable=SC2086
        device_part=$(df $MOUNT_POINT --output=source | tail -n +2)

        # shellcheck disable=SC2006
        device=/dev/$(lsblk -no pkname,MOUNTPOINT | grep "$MOUNT_POINT$" | awk '{print $1}')
        # shellcheck disable=SC2006
        # shellcheck disable=SC2086
        device_part_num=$(gdisk $device -l | awk '{last_line=$0} END{print $1}')
        # shellcheck disable=SC2006
        # shellcheck disable=SC2086
        disk_type=$(parted -s $device print | grep "Partition Table" | awk '{print $3}')
        if [ "$disk_type" != "gpt" ]; then
                echo "Only supports GPT disk type."
                # shellcheck disable=SC2242
                exit -1
        fi
        # shellcheck disable=SC2086
        last_part_start=$(fdisk $device -l | grep $device | awk '{last_line=$0} END{print $2}')
        # shellcheck disable=SC2086
        rootfs_start=$(fdisk $device -l | grep $device_part | awk 'NR == 1{print $2}')

        if [ "$last_part_start" != "$rootfs_start" ]; then
                echo "Unsupported partition format. The root partition is not at the end, or the root partition is not the largest partition."
                # shellcheck disable=SC2242
                exit -2
        fi

        # shellcheck disable=SC2006
        # shellcheck disable=SC2086
        fstype=$(lsblk $device_part -no FSTYPE,PATH | awk '{print $1}')

        if [ "$fstype" != "ext4" ]; then
                echo "Only supports ext4 fstype."
                # shellcheck disable=SC2242
                exit -1
        fi
}

create_service() {
        echo Create service...
        # shellcheck disable=SC2086
        echo "[Unit]
Description=Auto grow the root part.
After=-.mount

[Service]
ExecStart=$GROW_SCRIPT
Type=oneshot

[Install]
WantedBy=multi-user.target
" >$MOUNT_POINT$GROW_SERVER

        # shellcheck disable=SC2086
        ln -s $MOUNT_POINT$GROW_SERVER $MOUNT_POINT/etc/systemd/system/multi-user.target.wants/ || true

        # shellcheck disable=SC2028
        # shellcheck disable=SC2086
        echo "#!/bin/bash
# Auto create by $SCRIPT_NAME

set -e
ROOT_PART=/dev/\`lsblk -no pkname,MOUNTPOINT | grep \"/$\" | awk '{print \$1}'\`
ROOT_PART_NO=$device_part_num
ROOT_DEV=\`lsblk -no PATH,MOUNTPOINT | grep \"/$\" | awk '{print \$1}'\`

# fix disk size
echo w | fdisk \$ROOT_PART

echo -e \"resizepart \$ROOT_PART_NO 100%\ny\" | parted ---pretend-input-tty \$ROOT_PART

# ext4 part only
resize2fs \$ROOT_DEV

# disabled server
systemctl disable $GROW_SERVER_NAME
" >$MOUNT_POINT$GROW_SCRIPT

        # shellcheck disable=SC2086
        chmod +x $MOUNT_POINT$GROW_SCRIPT
}

install_tools() {
        commands="rsync parted gdisk fdisk kpartx tune2fs losetup "
        packages="rsync parted gdisk fdisk kpartx e2fsprogs util-linux"

        idx=1
        need_packages=""
        for cmd in $commands; do
                # shellcheck disable=SC2086
                if ! command -v $cmd >/dev/null; then
                        pkg=$(echo "$packages" | cut -d " " -f $idx)
                        printf "%-30s %s\n" "Command not found: $cmd", "package required: $pkg"
                        need_packages="$need_packages $pkg"
                fi
                ((++idx))
        done

        if [ "$need_packages" != "" ]; then
                confirm "Do you want to apt-get install the packages?" "abort"
                apt-get update
                # shellcheck disable=SC2086
                apt-get install -y --no-install-recommends $need_packages
                echo '--------------------'
        fi
}

gen_image_size() {
        if [ "$output" == "" ]; then
                output="${PWD}/${model}-backup-$(date +%y%m%d-%H%M).img"
        else
                if [ "${output:(-4)}" == ".img" ]; then
                        # shellcheck disable=SC2086
                        output=$(realpath $output)
                        # shellcheck disable=SC2046
                        # shellcheck disable=SC2086
                        mkdir -p $(dirname $output)
                else
                        # shellcheck disable=SC2086
                        output=$(realpath $output)
                        mkdir -p "$output"
                        output="${output%/}/${model}-backup-$(date +%y%m%d-%H%M).img"
                fi
        fi

        # shellcheck disable=SC2086
        rootfs_size=$(df -B512 $MOUNT_POINT | awk 'NR == 2{print $3}')
        # shellcheck disable=SC2003
        # shellcheck disable=SC2086
        backup_size=$(expr $rootfs_size + $rootfs_start + 40 + 1000000)
}

check_avail_space() {
        output_=${output}
        while true; do
                store_size=$(df -B512 | grep "$output_\$" | awk '{print $4}' | sed 's/M//g')
                if [ "$store_size" != "" ] || [ "$output_" == "\\" ]; then
                        break
                fi
                # shellcheck disable=SC2086
                output_=$(dirname $output_)
        done

        # shellcheck disable=SC2046
        # shellcheck disable=SC2003
        # shellcheck disable=SC2086
        if [ $(expr ${store_size} - ${backup_size}) -lt 64 ]; then
                echo -e "No space left on ${output_}\nAborted.\n"
                exit 1
        fi

        return 0
}

rebuild_root_partition() {
        echo Rebuild root partition...

        echo Delete inappropriate partition and fix
        # shellcheck disable=SC2086
        echo -e "d\n$device_part_num\nw\ny" | gdisk $output >/dev/null 2>&1

        # get partition infomations
        # shellcheck disable=SC2155
        # shellcheck disable=SC2006
        # shellcheck disable=SC2086
        local type=$(echo -e "x\ni\n$device_part_num\n" | gdisk $device | grep "Partition GUID code:" | awk '{print $12}')
        # shellcheck disable=SC2155
        # shellcheck disable=SC2006
        # shellcheck disable=SC2086
        local guid=$(echo -e "x\ni\n$device_part_num\n" | gdisk $device | grep "Partition unique GUID:" | awk '{print $4}')
        # shellcheck disable=SC2006
        # shellcheck disable=SC2086
        local attribute_flags=$((16#$(echo -e "x\ni\n$device_part_num\n" | gdisk $device | grep "Attribute flags:" | awk '{print $3}')))
        # shellcheck disable=SC2155
        # shellcheck disable=SC2006
        # shellcheck disable=SC2086
        local _partition_name=$(echo -e "x\ni\n$device_part_num\n" | gdisk $device | grep "Partition name:" | awk '{print $3}')
        local partition_name=${_partition_name:1:-1}

        echo Create new root partition...
        # shellcheck disable=SC2086
        echo -e "n\n$device_part_num\n$rootfs_start\n\n\nw\ny\n" | gdisk $output >/dev/null 2>&1

        echo Change part GUID
        # shellcheck disable=SC2086
        echo -e "x\nc\n$device_part_num\n$guid\nw\ny\n" | gdisk $output >/dev/null 2>&1

        echo Change part Label
        # shellcheck disable=SC2086
        echo -e "c\n$device_part_num\n$partition_name\nw\ny\n" | gdisk $output >/dev/null 2>&1

        echo Change part type
        # shellcheck disable=SC2086
        echo -e "t\n$device_part_num\n$type\nw\ny\n" | gdisk $output >/dev/null 2>&1

        echo Change attribute_flag
        flag_str=""
        local t=0

        while [ $attribute_flags -ne 0 ]; do
                echo $attribute_flags
                if (((attribute_flags & 1) != 0)); then
                        flag_str="$flag_str$t\n"
                fi
                ((attribute_flags = attribute_flags >> 1)) || true
                ((t = t + 1))
        done
        # shellcheck disable=SC2086
        echo -e "x\na\n$device_part_num\n$flag_str\nw\ny\n" | gdisk $output >/dev/null 2>&1
}

# shellcheck disable=SC1009
backup_image() {
        echo "Generate the base images. This might take some time."
        # shellcheck disable=SC2086
        dd if=/dev/zero of=${output} bs=512 count=0 seek=$backup_size status=progress

        echo "Copy other partition"
        # shellcheck disable=SC2086
        # shellcheck disable=SC2046
        # shellcheck disable=SC2003
        dd if=$device of=$output bs=512 seek=0 count=$(expr $rootfs_start - 1) status=progress conv=notrunc

        rebuild_root_partition

        echo Mount loop device...
        # shellcheck disable=SC2086
        loopdevice=$(losetup -f --show $output)
        # shellcheck disable=SC2086
        mapdevice="/dev/mapper/$(kpartx -va $loopdevice | sed -E 's/.*(loop[0-9]+)p.*/\1/g' | head -1)"
        sleep 2 # waiting for kpartx

        loop_root_dev=${mapdevice}p$device_part_num

        echo Format root partition...
        # shellcheck disable=SC2086
        mkfs.ext4 $loop_root_dev >/dev/null 2>&1

        # shellcheck disable=SC2086
        e2fsck -f -y $loop_root_dev >/dev/null 2>&1

        # shellcheck disable=SC2046
        # shellcheck disable=SC2006
        # shellcheck disable=SC2086
        echo y | tune2fs -U $(lsblk $device_part -no UUID) $loop_root_dev >/dev/null

        echo Mounting...
        # shellcheck disable=SC2086
        mount $loop_root_dev $ROOT_MOUNT

        echo Start rsync...

        # shellcheck disable=SC2086
        # shellcheck disable=SC1073
        rsync --force -rltWDEHSgopAXx --delete --stats --info=progress2 $exclude \
                --exclude "$output" \
                --exclude .gvfs \
                --exclude /dev \
                --exclude /media \
                --exclude /mnt \
                --exclude /proc \
                --exclude /run \
                --exclude /sys \
                --exclude /tmp \
                --exclude lost+found \
                $MOUNT_POINT/ $ROOT_MOUNT
        local result=$?
        # special dirs
        for i in dev media mnt proc run sys tmp; do
                # shellcheck disable=SC2086
                if [ ! -d $ROOT_MOUNT/$i ]; then
                        # shellcheck disable=SC2086
                        mkdir $ROOT_MOUNT/$i
                fi
        done

        # shellcheck disable=SC2086
        chmod a+w $ROOT_MOUNT/tmp

        sync
        # shellcheck disable=SC2086
        umount $ROOT_MOUNT && rm -rf $ROOT_MOUNT
        # shellcheck disable=SC2086
        losetup -d $loopdevice
        # shellcheck disable=SC2086
        kpartx -d $loopdevice

        # shellcheck disable=SC2086
        rm $MOUNT_POINT/etc/systemd/system/multi-user.target.wants/$GROW_SERVER_NAME.service

        if [ $result -ne 0 ]; then
                echo Warning: There may be issues during the execution of rsync, and the image may fail to start.
        fi

        echo -e "\nBackup done, the file is ${output}"
}

usage() {
        echo -e "Usage:\n  sudo ./${SCRIPT_NAME} [-o path|-e pattern|-u|-m path]"
        # shellcheck disable=SC2016
        echo '    -o Specify output position, default is $PWD.'
        echo '    -e Exclude files matching pattern for rsync.'
        echo '    -u Unattended, no need to confirm in the backup process.'
        echo '    -m Back up the root mount point, and support backups from other disks as well.'
}

main() {
        check_root

        echo -e "  Enter ${SCRIPT_NAME} -h to view help."
        echo '--------------------'
        install_tools
        check_part
        gen_image_size
        check_avail_space

        printf "The backup file will be saved at %s\n" "$output"
        # shellcheck disable=SC2003
        # shellcheck disable=SC2086
        printf "After this operation, %s MB of additional disk space will be used.\n" "$(expr $backup_size / 2048)"
        confirm "Do you want to continue?" "abort"
        create_service
        backup_image
}

# shellcheck disable=SC2068
get_option $@
if [ "$print_help" == "1" ]; then
        usage
else
        main
fi
# end
