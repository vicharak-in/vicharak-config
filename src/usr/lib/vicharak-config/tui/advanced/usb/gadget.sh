# shellcheck shell=bash

GADGET_DIR="/sys/kernel/config/usb_gadget/vicharak"

# Initialize USB Gadget directory
__usb_init_gadget() {
	if [[ ! -d "/sys/kernel/config/usb_gadget" ]]; then
		echo "Error: USB Gadget support is not enabled in the kernel."
		return 1
	fi

	if [[ -d "$GADGET_DIR" ]]; then
		echo "USB gadget directory already exists, skipping..."
		return
	fi

	mkdir -p "$GADGET_DIR"

	echo 0x1d6b > "$GADGET_DIR/idVendor"
	echo 0x0104 > "$GADGET_DIR/idProduct"
	echo 0x0100 > "$GADGET_DIR/bcdDevice"
	echo 0x0300 > "$GADGET_DIR/bcdUSB"

	mkdir -p "$GADGET_DIR/strings/0x409"
	echo "5fdef992060a0a669b" > "$GADGET_DIR/strings/0x409/serialnumber"
	echo "Vicharak" > "$GADGET_DIR/strings/0x409/manufacturer"
	echo "USB Gadget" > "$GADGET_DIR/strings/0x409/product"

	mkdir -p "$GADGET_DIR/configs/c.1/strings/0x409"
}

# Set UDC devices for USB gadget
__usb_enable_gadget() {
	if [[ -s "$GADGET_DIR/UDC" && -n $(cat "$GADGET_DIR/UDC") ]]; then
		echo "USB gadget is already enabled on $(cat "$GADGET_DIR/UDC")"
		return
	fi

	UDC_DEFAULT=$(find /sys/class/udc -mindepth 1 -maxdepth 1 -printf "%f\n" | tail -n 1)
	if [[ -z "$UDC_DEFAULT" ]]; then
		echo "No available UDC found."
		return 1
	fi

	echo "$UDC_DEFAULT" > "$GADGET_DIR/UDC"
	echo "USB Gadget enabled on $UDC_DEFAULT"
}

__usb_disable_gadget() {
	if [[ ! -d "$GADGET_DIR" ]]; then
		echo "USB gadget is not initialized."
		return
	fi

	# Check if UDC is set and disable it
	if [[ -s "$GADGET_DIR/UDC" ]]; then
		echo "" > "$GADGET_DIR/UDC"
		echo "USB Gadget disabled."
	fi
}

__usb_cleanup_gadget() {
	if [[ ! -d "$GADGET_DIR" ]]; then
		echo "No USB gadget found to clean up."
		return
	fi

	echo "Cleaning up USB gadget..."
	rm -rf "$GADGET_DIR"
	echo "USB gadget removed."
}
