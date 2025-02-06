# shellcheck shell=bash

# shellcheck source=src/usr/lib/vicharak-config/mod/overlay.sh
source "/usr/lib/vicharak-config/mod/overlay.sh"

ALLOWED_VICHARAK_CONFIG_FUNC+=("load_u-boot_setting")

check_overlay_conflict_init() {
	VICHARAK_CONFIG_OVERLAY_RESOURCES=()
	VICHARAK_CONFIG_OVERLAY_RESOURCE_OWNER=()
}

check_overlay_conflict_cli() {
	local name resources res i
	mapfile -t resources < <(parse_dtbo "$1" "exclusive")
	mapfile -t name < <(parse_dtbo "$1" "title" "$(basename "$1")")

	for res in "${resources[@]}"; do
		if [[ "$res" == "null" ]]; then
			continue
		fi
		if i="$(__in_array "$res" "${VICHARAK_CONFIG_OVERLAY_RESOURCES[@]}")"; then
			echo "Resource conflict detected!

'${name[0]}' and '${VICHARAK_CONFIG_OVERLAY_RESOURCE_OWNER[$i]}' both require the exclusive ownership of the following resource:

${VICHARAK_CONFIG_OVERLAY_RESOURCES[$i]}

Please only enable one of them." >&2
			return 1
		else
			VICHARAK_CONFIG_OVERLAY_RESOURCES+=("$res")
			VICHARAK_CONFIG_OVERLAY_RESOURCE_OWNER+=("${name[0]}")
		fi
	done
}

check_overlay_conflict() {
	local name resources res i
	mapfile -t resources < <(parse_dtbo "$1" "exclusive")
	mapfile -t name < <(parse_dtbo "$1" "title" "$(basename "$1")")

	for res in "${resources[@]}"; do
		if [[ "$res" == "null" ]]; then
			continue
		fi
		if i="$(__in_array "$res" "${VICHARAK_CONFIG_OVERLAY_RESOURCES[@]}")"; then
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
	if [[ ! -e "/etc/default/u-boot" ]]; then
		touch "/etc/default/u-boot"
	fi

	# shellcheck source=/dev/null
	source "/etc/default/u-boot"

	if [[ -z "${U_BOOT_TIMEOUT:-}" ]]; then
		if ! grep -q "^U_BOOT_TIMEOUT" "/etc/default/u-boot"; then
			echo 'U_BOOT_TIMEOUT="10"' >>"/etc/default/u-boot"
		fi
		sed -i "s/^U_BOOT_TIMEOUT=.*/U_BOOT_TIMEOUT=\"10\"/g" "/etc/default/u-boot"
	fi
	if [[ -z "${U_BOOT_PARAMETERS:-}" ]]; then
		if ! grep -q "^U_BOOT_PARAMETERS" "/etc/default/u-boot"; then
			echo "U_BOOT_PARAMETERS=\"\$(cat \"\/etc/kernel/cmdline\")\"" >>"/etc/default/u-boot"
		fi
		sed -i "s|^U_BOOT_PARAMETERS=.*|U_BOOT_PARAMETERS=\"\$(cat /etc/kernel/cmdline)\"|g" "/etc/default/u-boot"
	fi

	# shellcheck source=/dev/null
	source "/etc/default/u-boot"
	U_BOOT_FDT_OVERLAYS_DIR="/boot/overlays-$(uname -r)"
}

disable_overlays() {
	load_u-boot_setting

	for i in "$U_BOOT_FDT_OVERLAYS_DIR"/*.dtbo; do
		mv -- "$i" "${i}.disabled"
	done
}

__reset_overlays_worker() {
	local overlay="$1" new_overlays="$2"

	if dtbo_is_compatible "$overlay"; then
		if [[ ${overlay} =~ \.disabled$ ]]; then
			# Remove all the enabled overlays if any
			rm -f "$new_overlays/$(basename "${overlay%.disabled}")"

			# Copy back the overlays from the disabled state
			cp "$overlay" "$new_overlays/$(basename "$overlay")"

			# Save the basename of the overlay to the managed list
			exec 100>>"$new_overlays/managed.list"
			flock 100
			basename "$overlay" >&100
		fi
	fi
}

reset_overlays() {
	load_u-boot_setting

	local version="$1" vendor="$2" keep_active_enabled="$3" dtbos i
	local old_overlays new_overlays enabled_overlays=()
	local keep_enabled=()
	old_overlays="$(realpath "$U_BOOT_FDT_OVERLAYS_DIR")"
	new_overlays="${old_overlays}_new"

	# Save old enabled overlays
	if [[ ${keep_active_enabled} == "true" ]]; then
		while read -r overlay; do
			keep_enabled+=("$(basename "${overlay}")")
			echo "Enabled overlays = ${overlay}" >&2
		done < <(find "${old_overlays}" -name "*.dtbo")
	fi

	if [[ -d "$old_overlays" ]]; then
		cp -aR "$old_overlays" "$new_overlays"
	else
		mkdir -p "$old_overlays" "$new_overlays"
	fi

	if [[ -f "$new_overlays/managed.list" ]]; then
		mapfile -t VICHARAK_CONFIG_MANAGED_OVERLAYS <"$new_overlays/managed.list"

		for i in "${VICHARAK_CONFIG_MANAGED_OVERLAYS[@]}"; do
			if [[ -f "$new_overlays/$i" ]]; then
				enabled_overlays+=("$i")
				rm -f "$new_overlays/$i"
			fi
			rm -f "$new_overlays/$i.disabled"
		done
	fi

	if [[ -n "$vendor" ]]; then
		dtbos=("/usr/lib/linux-image-$version/$vendor/overlays/"*.dtbo*)
	else
		dtbos=("/usr/lib/linux-image-$version/"*"/overlays/"*.dtbo*)
	fi
	rm -f "$new_overlays/managed.list"
	touch "$new_overlays/managed.list"
	for i in "${dtbos[@]}"; do
		if [[ ! -f /sys/firmware/devicetree/base/compatible ]]; then
			# Assume we are running at image building stage
			# Do not fork out so we don't trigger OOM killer
			__reset_overlays_worker "$i" "$new_overlays"
		else
			__reset_overlays_worker "$i" "$new_overlays" &
		fi
	done
	wait

	for i in "${enabled_overlays[@]}"; do
		if [[ -f "$new_overlays/${i}.disabled" ]]; then
			mv -- "$new_overlays/${i}.disabled" "$new_overlays/$i"
		fi
	done

	if [[ ${keep_active_enabled} == "true" ]]; then
		for i in "${keep_enabled[@]}"; do
			if [[ -f "$new_overlays/${i}.disabled" ]]; then
				mv -- "$new_overlays/${i}.disabled" "$new_overlays/$i"
			fi
		done
	fi

	rm -rf "${old_overlays}_old"
	mv "$old_overlays" "${old_overlays}_old"
	mv "$new_overlays" "$old_overlays"
}

parse_dtbo() {
	local output
	output="$(dtc -I dtb -O dts "$1" 2>/dev/null | dtc -I dts -O yaml 2>/dev/null | yq -r ".[0][].__overlay__.metadata.$2[0]" | tr '\0' '\n')"

	if [[ "${output}" == "null" ]]; then
		# Try parsing the metadata property with an alternative path
		output="$(dtc -I dtb -O dts "$1" 2>/dev/null | dtc -I dts -O yaml 2>/dev/null | yq -r ".[0].fragment@0.__overlay__.metadata.$2[0]" | tr '\0' '\n')"
	fi

	if (($# >= 3)); then
		if [[ "${output}" == "null" ]]; then
			echo "$3"
			return
		fi
	fi
	echo "${output}"
}

dtbo_is_compatible() {
	if [[ ! -f /sys/firmware/devicetree/base/compatible ]]; then
		# Assume we are running at image building stage
		# Skip checking
		return
	fi

	local overlay="$1" dtbo_compatible
	mapfile -t dtbo_compatible < <(parse_dtbo "$overlay" "compatible")
	if [[ "${dtbo_compatible[0]}" == "null" ]]; then
		return
	fi

	for d in "${dtbo_compatible[@]}"; do
		for p in $(xargs -0 </sys/firmware/devicetree/base/compatible); do
			if [[ "$d" == "$p" ]]; then
				return
			fi
		done
	done

	return 1
}
