# shellcheck shell=bash

config_transaction_start() {
	RBUILD_CONFIG="/userdata/config.txt.new"
	cp /userdata/config.txt "$RBUILD_CONFIG"
}

config_transaction_abort() {
	rm -f "$RBUILD_CONFIG"
	unset RBUILD_CONFIG
}

config_transaction_commit() {
	cp /userdata/config.txt /userdata/config.txt.old
	mv "$RBUILD_CONFIG" /userdata/config.txt
	unset RBUILD_CONFIG
}

remove_config() {
	local regex="$1"
	shift
	while (($# > 0)); do
		regex="$regex\s+$1"
		shift
	done
	sed -E -i "/^\s*$regex.*$/d" "$RBUILD_CONFIG"
}

add_config() {
	echo "$@" >>"$RBUILD_CONFIG"
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
