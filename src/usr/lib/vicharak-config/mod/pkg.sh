# shellcheck shell=bash

ALLOWED_VICHARAK_CONFIG_FUNC+=("remove_packages")

__depends_package() {
	local title="$1" p missing_packages=()
	shift
	for p in "$@"; do
		if ! dpkg -l "$p" &>/dev/null; then
			missing_packages+=("$p")
		fi
	done

	if ((${#missing_packages[@]} != 0)); then
		if ! yesno "'$title' requires the following packages:

${missing_packages[*]}

Do you want to install them right now?"; then
			return 1
		fi
		apt-get update
		apt-get install --no-install-recommends -y "${missing_packages[@]}"
	fi
}

__is_installed() {
	if dpkg -l "$@" &>/dev/null; then
		return 0
	else
		return 1
	fi
}

remove_packages() {
	apt-get autoremove -y "$@"
}
