# shellcheck shell=bash

__hardware_gpio_fmt() {
	local i="$1"
	if ((i < 4)); then
		# shellcheck disable=SC2028
		echo "%s      %s %s      %s\\n"
	elif ((i == 4)); then
		# shellcheck disable=SC2028
		echo "%s      %s %s     %s\\n"
	else
		# shellcheck disable=SC2028
		echo "%s     %s %s     %s\\n"
	fi
}

__get_gpio_pin_count() {
	if grep -a -i axon /sys/firmware/devicetree/base/model > /dev/null; then
		echo 30  # Axon model has 30 pins
	elif grep -a -i vaaman /sys/firmware/devicetree/base/model > /dev/null; then
		echo 40  # Vaaman model has 40 pins
	fi
}

__hardware_gpio_set() {
	local i level="$1" gpio=() states=()

	local gpio_pin_count
	gpio_pin_count=$(__get_gpio_pin_count)

	for i in $(seq 1 "$gpio_pin_count"); do
		if gpiofind "PIN_$i" >/dev/null; then
			read -ra gpio < <(gpiofind "PIN_$i")
			if gpioset "${gpio[0]}" "${gpio[1]}=$level"; then
				gpioset -m signal "${gpio[0]}" "${gpio[1]}=$level" &
				states+=("$level")
			else
				states+=("E")
			fi
		else
			states+=(" ")
		fi
	done

	msgbox "Following GPIO pins have their state changed temporarily:

0: Low | 1: High | E: Error

State  Pin  State
$(for i in {0..19}; do
		# shellcheck disable=SC2059
		printf "$(__hardware_gpio_fmt "$i")" \
			"${states[i * 2]}" "$((i * 2 + 1))" \
			"$((i * 2 + 2))" "${states[i * 2 + 1]}"
	done)" #" # Workaround VS Code incorrect code highlighting

	jobs -r -p | xargs -I{} kill -- {}
}

__hardware_gpio_set_high() {
	__hardware_gpio_set 1
}

__hardware_gpio_set_low() {
	__hardware_gpio_set 0
}

__hardware_gpio_get() {
	local i level gpio=() states=()

	local gpio_pin_count
	gpio_pin_count=$(__get_gpio_pin_count)

	for i in $(seq 1 "$gpio_pin_count"); do
		if gpiofind "PIN_$i" >/dev/null; then
			read -ra gpio < <(gpiofind "PIN_$i")
			if level="$(gpioget "${gpio[@]}" 2>/dev/null)"; then
				states+=("$level")
			else
				states+=("E")
			fi
		else
			states+=(" ")
		fi
	done

	msgbox "Following is the current reading of all supported GPIO pins:

0: Low | 1: High | E: Error

State  Pin  State
$(for i in {0..19}; do
		# shellcheck disable=SC2059
		printf "$(__hardware_gpio_fmt "$i")" \
			"${states[i * 2]}" "$((i * 2 + 1))" \
			"$((i * 2 + 2))" "${states[i * 2 + 1]}"
	done)

-----------------------------------------------------------------------------
Note:   You are reading GPIO pins configured in input mode on the header.
        This setup allows for sensing voltage levels on the GPIO pins,
        rather than retrieving previously set output values.
-----------------------------------------------------------------------------"

}

__hardware_gpio() {
	if loginctl | grep -e ttyS -e ttyAML -e ttyFIQ >/dev/null &&
		! yesno "A serial session has been detected.

Testing GPIO with provided functions may cause the serial console to malfunction.
It will only return to normal working condition after a system reboot.

Do you want to continue?
"; then
		return
	fi

	menu_init
	menu_add __hardware_gpio_set_high "Set all GPIO to High"
	menu_add __hardware_gpio_set_low "Set all GPIO to Low"
	menu_add __hardware_gpio_get "Get all GPIO state"
	menu_show "Please select the test case:"
}
