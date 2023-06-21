# shellcheck shell=bash

if git status &>/dev/null && [[ -f "$PWD/usr/bin/rsetup" ]]
then
    ROOT_PATH="${ROOT_PATH:-"$PWD"}"
else
    ROOT_PATH="${ROOT_PATH:-"$PWD"}"
fi

source "${ROOT_PATH}/usr/lib/rsetup/mod/utils.sh"

source "${ROOT_PATH}/usr/lib/rsetup/cli/rconfig.sh"
source "${ROOT_PATH}/usr/lib/rsetup/cli/ssh.sh"
source "${ROOT_PATH}/usr/lib/rsetup/cli/system.sh"
source "${ROOT_PATH}/usr/lib/rsetup/cli/account.sh"
source "${ROOT_PATH}/usr/lib/rsetup/cli/docker.sh"
source "${ROOT_PATH}/usr/lib/rsetup/cli/u-boot-menu.sh"
source "${ROOT_PATH}/usr/lib/rsetup/cli/wi-fi.sh"
source "${ROOT_PATH}/usr/lib/rsetup/cli/kernel.sh"
source "${ROOT_PATH}/usr/lib/rsetup/cli/test/mpp.sh"

if $DEBUG
then
    source "${ROOT_PATH}/usr/lib/rsetup/mod/debug_utils.sh"
fi
