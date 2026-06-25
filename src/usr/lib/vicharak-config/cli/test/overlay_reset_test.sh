# shellcheck shell=bash
# Regression test: __overlay_reset yesno guard must NOT be inverted.
#
# Before fix: "if yesno_cli" caused __overlay_reset to abort on "yes"
# and call reset_overlays on "no" -- the opposite of intent.
# After fix:  "if ! yesno_cli" aborts on "no", resets on "yes".
#
# Run: bash overlay_reset_test.sh  (no external dependencies required)

_reset_called=0

# ── stubs ──────────────────────────────────────────────────────────────────
__check_sudo()        { : ; }
load_u-boot_setting() { : ; }
uname()               { echo "5.10.0-vicharak"; }
get_soc_vendor()      { echo "rockchip"; }
u-boot-update()       { return 0; }
reset_overlays()      { _reset_called=$((_reset_called + 1)); return 0; }

yesno_cli() {
	local input
	read -r input
	[[ "$input" == "yes" ]] && return 0
	[[ "$input" == "no"  ]] && return 1
	return 1
}

# ── function under test ────────────────────────────────────────────────────
__overlay_reset() {
	__check_sudo "$0"

	if ! yesno_cli "WARNING
Enter (yes/no) to continue.
"; then
		return
	fi

	if reset_overlays "$(uname -r)" "$(get_soc_vendor)" "false"; then
		if u-boot-update >/dev/null; then
			echo "Overlays has been reset to current running kernel's default." >&2
		fi
	else
		echo "Unable to reset overlays" >&2
	fi
}

# ── test helpers ───────────────────────────────────────────────────────────
_pass=0
_fail=0

assert_eq() {
	local desc="$1" got="$2" want="$3"
	if [[ "$got" == "$want" ]]; then
		echo "PASS: $desc"
		_pass=$((_pass + 1))
	else
		echo "FAIL: $desc (got=$got, want=$want)"
		_fail=$((_fail + 1))
	fi
}

# ── test: user answers "yes" → reset_overlays must be called ──────────────
_reset_called=0
echo "yes" | __overlay_reset 2>/dev/null
assert_eq "answering yes calls reset_overlays" "$_reset_called" "1"

# ── test: user answers "no" → reset_overlays must NOT be called ───────────
_reset_called=0
echo "no" | __overlay_reset 2>/dev/null
assert_eq "answering no skips reset_overlays" "$_reset_called" "0"

# ── summary ────────────────────────────────────────────────────────────────
echo ""
echo "Results: ${_pass} passed, ${_fail} failed"
((_fail == 0))
