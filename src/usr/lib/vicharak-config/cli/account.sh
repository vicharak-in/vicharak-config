# shellcheck shell=bash

ALLOWED_VICHARAK_CONFIG_FUNC+=("add_user" "update_password" "user_append_group" "remove_user")

add_user() {
	local username="$1"
	local password="$2"

	adduser --gecos "$username" --disabled-password "$username"

	if [[ -n "$password" ]]; then
		update_password "$username" "$password"
	else
		passwd -d "$username"
	fi
}

update_password() {
	__parameter_count_check 2 "$@"

	local username="$1"
	local password="$2"

	echo "$username:$password" | chpasswd
}

user_append_group() {
	__parameter_count_check 2 "$@"

	local username="$1"
	local group="$2"

	usermod -aG "$group" "$username"
}

remove_user() {
	__parameter_count_check 1 "$@"

	local username="$1"

	userdel -r "$username"
}
