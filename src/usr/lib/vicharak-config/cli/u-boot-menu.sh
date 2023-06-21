# shellcheck shell=bash
source "${ROOT_PATH}/usr/lib/vicharak-config/mod/overlay.sh"

ALLOWED_RCONFIG_FUNC+=("load_u-boot_setting")

check_overlay_conflict_init() {
    VICHARAK_CONFIG_OVERLAY_RESOURCES=()
    VICHARAK_CONFIG_OVERLAY_RESOURCE_OWNER=()
}

check_overlay_conflict() {
    local name resources res i
    mapfile -t resources < <(parse_dtbo "$1" "exclusive")
    mapfile -t name < <(parse_dtbo "$1" "title" "$(basename "$1")")

    for res in "${resources[@]}"
    do
        if [[ "$res" == "null" ]]
        then
            continue
        fi
        if i="$(__in_array "$res" "${VICHARAK_CONFIG_OVERLAY_RESOURCES[@]}")"
        then
            msgbox "Resource conflict detected!

'${name[0]}' and '${VICHARAK_CONFIG_OVERLAY_RESOURCE_OWNER[$i]}' both require the exclusive ownership of the following resource:

${VICHARAK_CONFIG_OVERLAY_RESOURCES[$i]}

Please only enable one of them."
            return 1
        else
            VICHARAK_CONFIG_OVERLAY_RESOURCES+=("$res")
            VICHARAK_CONFIG_OVERLAY_RESOURCE_OWNER+=("${name[0]}")
        fi
    done
}

load_u-boot_setting() {
    if [[ ! -e "/userdata/u-boot" ]]
    then
        touch "/userdata/u-boot"
    fi

    # shellcheck source=/dev/null
    source "/userdata/u-boot"

    if [[ -z "${U_BOOT_TIMEOUT:-}" ]]
    then
        if ! grep -q "^U_BOOT_TIMEOUT" "/userdata/u-boot"
        then
            echo 'U_BOOT_TIMEOUT="10"' >> "/userdata/u-boot"
        fi
        sed -i "s/^U_BOOT_TIMEOUT=.*/U_BOOT_TIMEOUT=\"10\"/g" "/userdata/u-boot"
    fi
    if [[ -z "${U_BOOT_PARAMETERS:-}" ]]
    then
        if ! grep -q "^U_BOOT_PARAMETERS" "/userdata/u-boot"
        then
            echo "U_BOOT_PARAMETERS=\"\$(cat \"\/boot/cmdline\")\"" >> "/userdata/u-boot"
        fi
        sed -i "s|^U_BOOT_PARAMETERS=.*|U_BOOT_PARAMETERS=\"\$(cat /boot/cmdline)\"|g" "/userdata/u-boot"
    fi

    # shellcheck source=/dev/null
    source "/userdata/u-boot"

    if [[ -z "${U_BOOT_FDT_OVERLAYS_DIR:-}" ]]
    then
		eval "$(grep "^U_BOOT_FDT_OVERLAYS_DIR" "$(command -v u-boot-update)")"
        U_BOOT_FDT_OVERLAYS_DIR="${U_BOOT_FDT_OVERLAYS_DIR:-}"
    fi
}

disable_overlays() {
    load_u-boot_setting

    for i in "$U_BOOT_FDT_OVERLAYS_DIR"/*.dtbo
    do
        mv -- "$i" "${i}.disabled"
    done
}

__reset_overlays_worker() {
    local overlay="$1" new_overlays="$2"

    if dtbo_is_compatible "$overlay"
    then
        cp "$overlay" "$new_overlays/$(basename "$overlay").disabled"
        exec 100>>"$new_overlays/managed.list"
        flock 100
        basename "$overlay" >&100
    fi
}

reset_overlays() {
    load_u-boot_setting

    local version="$1" vendor="$2" dtbos i
    local old_overlays new_overlays enabled_overlays=()
    old_overlays="$(realpath "$U_BOOT_FDT_OVERLAYS_DIR")"
    new_overlays="${old_overlays}_new"
    if [[ -d "$old_overlays" ]]
    then
        cp -aR "$old_overlays" "$new_overlays"
    else
        mkdir -p "$old_overlays" "$new_overlays"
    fi

    if [[ -f "$new_overlays/managed.list" ]]
    then
        mapfile -t VICHARAK_CONFIG_MANAGED_OVERLAYS < "$new_overlays/managed.list"

        for i in "${VICHARAK_CONFIG_MANAGED_OVERLAYS[@]}"
        do
            if [[ -f "$new_overlays/$i" ]]
            then
                enabled_overlays+=( "$i" )
                rm -f "$new_overlays/$i"
            fi
            rm -f "$new_overlays/$i.disabled"
        done
    fi

    if [[ -n "$vendor" ]]
    then
        dtbos=( "/usr/lib/linux-image-$version/$vendor/overlays/"*.dtbo* )
    else
        dtbos=( "/usr/lib/linux-image-$version/"*"/overlays/"*.dtbo* )
    fi
    rm -f "$new_overlays/managed.list"
    touch "$new_overlays/managed.list"
    for i in "${dtbos[@]}"
    do
        if [[ ! -f /sys/firmware/devicetree/base/compatible ]]
        then
            # Assume we are running at image building stage
            # Do not fork out so we don't trigger OOM killer
            __reset_overlays_worker "$i" "$new_overlays"
        else
            __reset_overlays_worker "$i" "$new_overlays" &
        fi
    done
    wait

    for i in "${enabled_overlays[@]}"
    do
        if [[ -f "$new_overlays/${i}.disabled" ]]
        then
            mv -- "$new_overlays/${i}.disabled" "$new_overlays/$i"
        fi
    done

    rm -rf "${old_overlays}_old"
    mv "$old_overlays" "${old_overlays}_old"
    mv "$new_overlays" "$old_overlays"
}

parse_dtbo() {
    local output
    output="$(dtc -I dtb -O dts "$1" 2>/dev/null | dtc -I dts -O yaml 2>/dev/null | yq -r ".[0].metadata.$2[0]" | tr '\0' '\n')"

    if (( $# >= 3 ))
    then
        if [[ "${output}" == "null" ]]
        then
            echo "$3"
            return
        fi
    fi
    echo "${output}"
}

dtbo_is_compatible() {
    if [[ ! -f /sys/firmware/devicetree/base/compatible ]]
    then
        # Assume we are running at image building stage
        # Skip checking
        return
    fi

    local overlay="$1" dtbo_compatible
    mapfile -t dtbo_compatible < <(parse_dtbo "$overlay" "compatible")
    if [[ "${dtbo_compatible[0]}" == "null" ]]
    then
        return
    fi

    for d in "${dtbo_compatible[@]}"
    do
        for p in $(xargs -0 < /sys/firmware/devicetree/base/compatible)
        do
            if [[ "$d" == "$p" ]]
            then
                return
            fi
        done
    done

    return 1
}
