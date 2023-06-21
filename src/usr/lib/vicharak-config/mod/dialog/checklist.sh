# shellcheck shell=bash

# shellcheck disable=SC2120
checklist_init() {
    __parameter_count_check 0 "$@"

    export VICHARAK_CONFIG_CHECKLIST=()
    export VICHARAK_CONFIG_CHECKLIST_VALUE=()
    export VICHARAK_CONFIG_CHECKLIST_STATE_OLD=()
    export VICHARAK_CONFIG_CHECKLIST_STATE_NEW=()
}

checklist_add() {
    local title="$1"
    local status="$2"
    local tag="$((${#VICHARAK_CONFIG_CHECKLIST[@]} / 3))"
    local value="${3:-$title}"

    __parameter_value_check "$status" "ON" "OFF"

    VICHARAK_CONFIG_CHECKLIST+=( "$tag" "$title" "$status" )
    VICHARAK_CONFIG_CHECKLIST_VALUE+=( "$value" )

    if [[ $status == "ON" ]]
    then
        VICHARAK_CONFIG_CHECKLIST_STATE_OLD+=( "$tag" )
    fi
}

checklist_show() {
    __parameter_count_check 1 "$@"

    if (( ${#VICHARAK_CONFIG_CHECKLIST[@]} == 0))
    then
        return 2
    fi

    local output i
    if output="$(__dialog --checklist "$1" "${VICHARAK_CONFIG_CHECKLIST[@]}" 3>&1 1>&2 2>&3 3>&-)"
    then
        read -r -a VICHARAK_CONFIG_CHECKLIST_STATE_NEW <<< "$output"
        for i in $(seq 2 3 ${#VICHARAK_CONFIG_CHECKLIST[@]})
        do
            VICHARAK_CONFIG_CHECKLIST[i]="OFF"
        done
        for i in "${VICHARAK_CONFIG_CHECKLIST_STATE_NEW[@]}"
        do
            i="${i//\"}"
            VICHARAK_CONFIG_CHECKLIST[i * 3 + 2]="ON"
        done
    else
        return 1
    fi
}

checklist_getitem() {
    __parameter_count_check 1 "$@"

    echo "${VICHARAK_CONFIG_CHECKLIST_VALUE[${1//\"}]}"
}

checklist_emptymsg() {
    __parameter_count_check 1 "$@"

    if (( ${#VICHARAK_CONFIG_CHECKLIST[@]} == 0))
    then
        msgbox "$1"
    fi
}
