# shellcheck shell=bash
if git status &>/dev/null && [[ -f "$PWD/usr/bin/rsetup" ]]
then
    ROOT_PATH="${ROOT_PATH:-"$PWD"}"
else
    ROOT_PATH="${ROOT_PATH:-}"
fi
source "${ROOT_PATH}/usr/lib/rsetup/mod/tui.sh"

source "${ROOT_PATH}/usr/lib/rsetup/tui/overlay/overlay.sh"
source "${ROOT_PATH}/usr/lib/rsetup/tui/comm/comm.sh"
source "${ROOT_PATH}/usr/lib/rsetup/tui/hardware/hardware.sh"
source "${ROOT_PATH}/usr/lib/rsetup/tui/local/local.sh"
source "${ROOT_PATH}/usr/lib/rsetup/tui/system/system.sh"
source "${ROOT_PATH}/usr/lib/rsetup/tui/task/task.sh"
source "${ROOT_PATH}/usr/lib/rsetup/tui/user/user.sh"

if $DEBUG
then
    source "${ROOT_PATH}/usr/lib/rsetup/tui/test/test.sh"
fi

__tui_about() {
    msgbox "rsetup - Radxa system setup utility

Copyright 2022-$(date +%Y) Radxa Computer Co., Ltd"
}

__tui_main() {
    menu_init
    menu_add __system "System Maintaince"
    menu_add __hardware "Hardware"
    menu_add __overlay "Overlays"
    menu_add __comm "Connectivity"
    menu_add __user "User Settings"
    menu_add __local "Localization"
    if $DEBUG
    then
        menu_add __task "Common Tasks"
        menu_add __test "TUI Test"
    fi
    menu_add __tui_about "About"
    menu_show "Please select an option below:"
}
