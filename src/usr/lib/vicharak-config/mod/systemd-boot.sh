# shellcheck shell=bash

# Main module that provides support for systemd-boot (Boot Loader Specification) systems
# 
# On such systems boot entries are managed by kernel-install
# (90-loaderentry.install)
#
# Edited By : Vivek Ray <vk092kumar@gmail.com>
# Edited On : 14 Nov 2026

get_boot_mode() {
	if [[ -e "/usr/lib/kernel/install.d/90-loaderentry.install" ]] && [[ -d "/boot/efi/loader/entries" ]]; then
		echo "systemd-boot"
	else
		echo "u-boot-menu"
	fi
}

# Locate the ESP ($BOOT). Covers both /boot/efi-style mounts and layout=bls
# where the ESP (or XBOOTLDR) is mounted at /boot directly.
get_esp() {
	local esp
	for esp in /boot/efi /efi /boot; do
		if [[ -d "$esp/loader/entries" ]]; then
			echo "$esp"
			return
		fi
	done
	echo "/boot/efi"
}

# Entry token used for the $BOOT/<token>/<version> directory layout
# ("layout=lsb"). Debian images use "debian".
get_entry_token() {
	if [[ -f /etc/kernel/entry-token ]]; then
		head -n 1 /etc/kernel/entry-token
	else
		echo "debian"
	fi
}

# Entry id (without .conf) of the entry the system is currently booted from.
get_systemd_boot_current_entry() {
	local id
	id="$(bootctl status 2>/dev/null | awk '/^Current Entry:/{print $3; exit}')"
	if [[ -n "$id" ]]; then
		echo "${id%.conf}"
	fi
}

# Entry id (without .conf) of the default boot entry.
# Honors both exact ids and patterns (e.g. "debian-*") in loader.conf.
get_systemd_boot_default_entry() {
	local esp default status id
	esp="$(get_esp)"
	default="$(awk '/^default/{print $2; exit}' "$esp/loader/loader.conf" 2>/dev/null)"

	if [[ -n "$default" ]] && [[ -f "$esp/loader/entries/$default.conf" ]]; then
		echo "$default"
		return
	fi

	# Default is a pattern (e.g. "debian-*"), resolve with bootctl
	status="$(bootctl status 2>/dev/null || true)"
	id="$(awk '/^Default Boot Loader Entry:/{f=1} f && /^ *id:/{print $2; exit}' <<<"$status")"
	if [[ -n "$id" ]]; then
		echo "${id%.conf}"
		return
	fi

	# Fall back to the currently booted entry
	id="$(awk '/^Current Entry:/{print $3; exit}' <<<"$status")"
	if [[ -n "$id" ]]; then
		echo "${id%.conf}"
	fi
}

# Find the overlays directory that belongs to the given context:
#   1. Explicit kernel version (used during kernel upgrades, where the new
#      ABI's entry directory is named after the new version, not uname -r)
#   2. The entry the system is currently booted from
#   3. Any overlays dir under $BOOT/<token>/
get_systemd_boot_overlays_dir() {
	local version="${1:-}" esp token dir conf
	esp="$(get_esp)"
	token="$(get_entry_token)"

	if [[ -n "$version" ]]; then
		dir="$(find "$esp/$token/$version" -maxdepth 1 -type d -name 'overlays-*' 2>/dev/null | head -n 1)"
		if [[ -n "$dir" ]]; then
			echo "$dir"
			return
		fi
	fi

	conf="$esp/loader/entries/$(get_systemd_boot_current_entry).conf"
	if [[ -n "$(get_systemd_boot_current_entry)" ]] && [[ -f "$conf" ]]; then
		dir="$(sed -n 's/^devicetree[[:space:]]*//p' "$conf" | head -n 1)"
		if [[ -z "$dir" ]]; then
			dir="$(sed -n 's/^linux[[:space:]]*//p' "$conf" | head -n 1)"
		fi
		if [[ -n "$dir" ]]; then
			dir="$(dirname "$dir")"
			dir="$(find "$esp$dir" -maxdepth 1 -type d -name 'overlays-*' 2>/dev/null | head -n 1)"
			if [[ -n "$dir" ]]; then
				echo "$dir"
				return
			fi
		fi
	fi

	find "$esp/$token" -maxdepth 2 -type d -name 'overlays-*' 2>/dev/null | sort | head -n 1
}

# Equivalent of load_u-boot_setting() for systemd-boot systems.
# Sets U_BOOT_ESP and U_BOOT_FDT_OVERLAYS_DIR; the latter is intentionally
# the same variable name used by the u-boot-menu flow so that the rest of
# the overlay code works unchanged.
load_systemd-boot_setting() {
	local version="${1:-}" dir esp token
	esp="$(get_esp)"
	token="$(get_entry_token)"

	dir="$(get_systemd_boot_overlays_dir "$version")"
	U_BOOT_ESP="$esp"

	if [[ -n "$dir" ]]; then
		U_BOOT_FDT_OVERLAYS_DIR="$dir"
		return
	fi

	# Nothing deployed yet: use the conventional path so that
	# reset_overlays() can create it.
	if [[ -z "$version" ]]; then
		version="$(uname -r)"
	fi
	U_BOOT_FDT_OVERLAYS_DIR="$esp/$token/$version/overlays-$version"
	if [[ -n "${1:-}" ]]; then
		# Kernel-upgrade context: make realpath() in reset_overlays() work
		mkdir -p "$(dirname "$U_BOOT_FDT_OVERLAYS_DIR")" 2>/dev/null || true
	fi
}

# List the enabled overlays of an entry directory: the devicetree-overlay
# line of the currently booted BLS entry is the source of truth, mirroring
# U_BOOT_OVERLAYS in /etc/default/u-boot on u-boot-menu systems.
#
# Note: entry drop-ins (<id>.conf.d/) are NOT honored for devicetree-overlay
# by the systemd-boot build shipped on axon-mini (verified on target), so the
# line lives in the main entry file.
systemd_boot_list_enabled() {
	local overlays="$1" esp conf line path
	esp="$(get_esp)"

	conf="$esp/loader/entries/$(get_systemd_boot_current_entry).conf"
	[[ -f "$conf" ]] || return

	line="$(sed -n 's/^devicetree-overlay[[:space:]]*//p' "$conf" | head -n 1)"
	[[ -n "$line" ]] || return

	for path in $line; do
		# Only overlays of this entry directory
		[[ "$path" == *"$(basename "$overlays")"* ]] || continue
		echo "$overlays/$(basename "$path")"
	done
}

# Write the devicetree-overlay line of every entry that boots from the same
# entry directory as U_BOOT_FDT_OVERLAYS_DIR.
#
# The enabled set is derived from the files in the overlays directory
# (*.dtbo = enabled, *.dtbo.disabled = disabled). This is authoritative right
# after disable_overlays()/the manage flow, and after reset_overlays() which
# disables overlays that are not supposed to stay enabled on systemd-boot
# systems.
#
# kernel-install (90-loaderentry.install) regenerates the entry file on
# kernel upgrades, wiping this line; the kernel hook (__yz-update-overlays)
# calls update_boot_config() afterwards to write it back.
systemd_boot_update_entries() {
	local esp overlays parent conf rel_dir dtbo
	local enabled=()
	esp="${U_BOOT_ESP:-$(get_esp)}"
	overlays="${U_BOOT_FDT_OVERLAYS_DIR:?}"
	parent="$(dirname "$overlays")"
	rel_dir="${parent#"$esp"}"

	for dtbo in "$overlays"/*.dtbo; do
		[[ -f "$dtbo" ]] && enabled+=("${dtbo#"$esp"}")
	done

	for conf in "$esp"/loader/entries/*.conf; do
		[[ -f "$conf" ]] || continue
		# Only touch entries that boot from the same entry directory
		grep -qF " $rel_dir/linux" "$conf" || continue

		sed -i '/^devicetree-overlay[[:space:]]/d' "$conf"
		if ((${#enabled[@]} > 0)); then
			printf 'devicetree-overlay %s\n' "${enabled[*]}" >>"$conf"
		fi
	done
}

# Set the default boot entry in loader.conf.
set_systemd_boot_default() {
	local id="$1" esp
	esp="$(get_esp)"

	[[ -f "$esp/loader/entries/$id.conf" ]] || return 1

	if grep -q '^default[[:space:]]' "$esp/loader/loader.conf"; then
		sed -i "s/^default[[:space:]].*/default $id/" "$esp/loader/loader.conf"
	else
		printf 'default %s\n' "$id" >>"$esp/loader/loader.conf"
	fi
}
