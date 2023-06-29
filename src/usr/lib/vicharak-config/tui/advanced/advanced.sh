# shellcheck shell=bash
# shellcheck disable=SC1090

source "${ROOT_PATH}/usr/lib/vicharak-config/tui/advanced/docker/docker.sh"
source "${ROOT_PATH}/usr/lib/vicharak-config/tui/advanced/gpu/gpu.sh"
source "${ROOT_PATH}/usr/lib/vicharak-config/tui/advanced/ssh/ssh.sh"
source "${ROOT_PATH}/usr/lib/vicharak-config/tui/advanced/display/display.sh"

__advanced() {
    menu_init
    #menu_add __advanced_docker          "Docker"
    menu_add __advanced_gpu             "Mali GPU"
    menu_add __advanced_display         "Display Options"
    #menu_add __advanced_ssh             "SSH"
    menu_show "Please select an option below:"
}
