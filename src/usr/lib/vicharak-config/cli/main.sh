# shellcheck shell=bash
# shellcheck disable=SC1090

if git status &>/dev/null && [[ -f "$PWD/src/usr/bin/vicharak-config" ]]
then
    ROOT_PATH="${ROOT_PATH:-"$PWD"}/src"
else
    ROOT_PATH="${ROOT_PATH:-}"
fi

source "${ROOT_PATH}/usr/lib/vicharak-config/mod/utils.sh"

source "${ROOT_PATH}/usr/lib/vicharak-config/cli/account.sh"
source "${ROOT_PATH}/usr/lib/vicharak-config/cli/docker.sh"
source "${ROOT_PATH}/usr/lib/vicharak-config/cli/kernel.sh"
source "${ROOT_PATH}/usr/lib/vicharak-config/cli/gpu.sh"
source "${ROOT_PATH}/usr/lib/vicharak-config/cli/rconfig.sh"
source "${ROOT_PATH}/usr/lib/vicharak-config/cli/ssh.sh"
source "${ROOT_PATH}/usr/lib/vicharak-config/cli/system.sh"
source "${ROOT_PATH}/usr/lib/vicharak-config/cli/test/mpp.sh"
source "${ROOT_PATH}/usr/lib/vicharak-config/cli/u-boot-menu.sh"
source "${ROOT_PATH}/usr/lib/vicharak-config/cli/wi-fi.sh"

if $DEBUG
then
    source "${ROOT_PATH}/usr/lib/vicharak-config/mod/debug_utils.sh"
fi
