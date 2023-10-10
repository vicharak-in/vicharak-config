# shellcheck shell=bash

config_transaction_start() {
	VICHARAK_BUILD_CONFIG="/userdata/config.txt.new"
	cp /userdata/config.txt "$VICHARAK_BUILD_CONFIG"
}

config_transaction_abort() {
	rm -f "$VICHARAK_BUILD_CONFIG"
	unset VICHARAK_BUILD_CONFIG
}

config_transaction_commit() {
	cp /userdata/config.txt /userdata/config.txt.old
	mv "$VICHARAK_BUILD_CONFIG" /userdata/config.txt
	unset VICHARAK_BUILD_CONFIG
}

remove_config() {
	local regex="$1"
	shift
	while (($# > 0)); do
		regex="$regex\s+$1"
		shift
	done
	sed -E -i "/^\s*$regex.*$/d" "$VICHARAK_BUILD_CONFIG"
}

add_config() {
	echo "$@" >>"$VICHARAK_BUILD_CONFIG"
}

enable_config() {
	"$@"
	add_config "$@"
}

save_unique_config() {
	local command="$1"
	shift
	local arguments=("$@")
	config_transaction_start
	remove_config "$command"
	add_config "$command" "${arguments[@]}"
	config_transaction_commit
}

enable_unique_config() {
	local command="$1"
	shift
	local arguments=("$@") ret=0
	"$command" "${arguments[@]}" || ret=$?
	if ((ret == 0)); then
		save_unique_config "$command" "${arguments[@]}"
	else
		return $ret
	fi
}
