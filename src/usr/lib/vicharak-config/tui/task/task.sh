# shellcheck shell=bash
# shellcheck disable=SC1090

source "${ROOT_PATH}/usr/lib/vicharak-config/tui/task/docker/docker.sh"
source "${ROOT_PATH}/usr/lib/vicharak-config/tui/task/gpu/gpu.sh"
source "${ROOT_PATH}/usr/lib/vicharak-config/tui/task/ssh/ssh.sh"

__task() {
    menu_init
    #menu_add __task_docker          "Docker"
    menu_add __task_gpu             "Mali GPU"
    #menu_add __task_ssh             "SSH"
    menu_show "Please select an option below:"
}
