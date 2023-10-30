# shellcheck shell=bash

# shellcheck source=src/usr/lib/vicharak-config/mod/utils.sh
source "/usr/lib/vicharak-config/mod/utils.sh"

# shellcheck source=src/usr/lib/vicharak-config/cli/account.sh
source "/usr/lib/vicharak-config/cli/account.sh"
# shellcheck source=src/usr/lib/vicharak-config/cli/docker.sh
source "/usr/lib/vicharak-config/cli/docker.sh"
# shellcheck source=src/usr/lib/vicharak-config/cli/kernel.sh
source "/usr/lib/vicharak-config/cli/kernel.sh"
# shellcheck source=src/usr/lib/vicharak-config/cli/gpu.sh
source "/usr/lib/vicharak-config/cli/gpu.sh"
# shellcheck source=src/usr/lib/vicharak-config/cli/overlay.sh
source "/usr/lib/vicharak-config/cli/overlay.sh"
# shellcheck source=src/usr/lib/vicharak-config/cli/vicharak-config.sh
source "/usr/lib/vicharak-config/cli/vicharak-config.sh"
# shellcheck source=src/usr/lib/vicharak-config/cli/ssh.sh
source "/usr/lib/vicharak-config/cli/ssh.sh"
# shellcheck source=src/usr/lib/vicharak-config/cli/system.sh
source "/usr/lib/vicharak-config/cli/system.sh"
# shellcheck source=src/usr/lib/vicharak-config/cli/test/mpp.sh
source "/usr/lib/vicharak-config/cli/test/mpp.sh"
# shellcheck source=src/usr/lib/vicharak-config/cli/u-boot-menu.sh
source "/usr/lib/vicharak-config/cli/u-boot-menu.sh"
# shellcheck source=src/usr/lib/vicharak-config/cli/wi-fi.sh
source "/usr/lib/vicharak-config/cli/wi-fi.sh"

if $DEBUG; then
	# shellcheck source=src/usr/lib/vicharak-config/mod/debug_utils.sh
	source "/usr/lib/vicharak-config/mod/debug_utils.sh"
fi
