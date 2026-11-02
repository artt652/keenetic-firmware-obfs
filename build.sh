#!/usr/bin/env bash
# Builds a KeeneticOS image with internal OPKG storage (and, once the module
# patch is ready, wg-obfuscator support in the WireGuard kernel module).
#
#   ./build.sh --firmware Sprinter.bin --donor Hopper.bin [--model KN-3710] [--version 5.01.C.8.0-2]
#
#   --firmware  firmware of the target router, saved from its web interface
#   --donor     firmware of a router on the same platform that has storage
#               support (Hopper KN-3810 for Sprinter), SAME KeeneticOS version;
#               closed NDM storage modules are taken from it
#   --version   KeeneticOS version of both files (= keenetic-sdk tag);
#               detected from the firmware file name when omitted
#
# Firmware files and anything extracted from them are proprietary: they are
# never committed to this repository (see .gitignore).
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
MODEL=KN-3710
FIRMWARE=""
DONOR=""
VERSION=""
WORK="$HERE/work"
JOBS=$(nproc)

while [ $# -gt 0 ]; do
	case "$1" in
	--firmware) FIRMWARE=$(realpath "$2"); shift 2 ;;
	--donor)    DONOR=$(realpath "$2"); shift 2 ;;
	--model)    MODEL=$2; shift 2 ;;
	--version)  VERSION=$2; shift 2 ;;
	--jobs)     JOBS=$2; shift 2 ;;
	-h|--help)  sed -n 2,16p "$0"; exit 0 ;;
	*) echo "unknown option $1" >&2; exit 2 ;;
	esac
done

[ -f "$FIRMWARE" ] || { echo "--firmware is required" >&2; exit 2; }
[ -f "$DONOR" ] || { echo "--donor is required" >&2; exit 2; }
MODEL_DIR="$HERE/models/$MODEL"
[ -d "$MODEL_DIR" ] || { echo "no overlay for $MODEL in models/" >&2; exit 2; }

if [ -z "$VERSION" ]; then
	VERSION=$(basename "$FIRMWARE" | grep -oE '[0-9]+\.[0-9]+\.[A-Z]\.[0-9]+\.[0-9]+-[0-9]+' | head -1 || true)
	[ -n "$VERSION" ] || { echo "cannot detect the version from the file name, pass --version" >&2; exit 2; }
fi
DONOR_VERSION=$(basename "$DONOR" | grep -oE '[0-9]+\.[0-9]+\.[A-Z]\.[0-9]+\.[0-9]+-[0-9]+' | head -1 || true)
if [ -n "$DONOR_VERSION" ] && [ "$DONOR_VERSION" != "$VERSION" ]; then
	echo "donor firmware is $DONOR_VERSION, target is $VERSION: they must match" >&2
	exit 2
fi

msg() { echo -e "\e[1;33m== $*\e[0m"; }

clone_sdk() {
	local dir=$1
	if [ ! -d "$dir/.git" ]; then
		git clone --depth 1 --branch "$VERSION" https://github.com/keenetic/keenetic-sdk.git "$dir"
	fi
}

mkdir -p "$WORK"

# 1. Donor: unpack it in its own SDK tree to get the closed storage modules.
msg "Unpacking donor firmware $(basename "$DONOR")"
clone_sdk "$WORK/sdk-donor"
( cd "$WORK/sdk-donor" && [ -f .unpacked ] || { ./unpack.sh "$DONOR" && touch .unpacked; } )

# 2. Target SDK.
msg "Unpacking target firmware $(basename "$FIRMWARE")"
clone_sdk "$WORK/sdk"
( cd "$WORK/sdk" && [ -f .unpacked ] || { ./unpack.sh "$FIRMWARE" && touch .unpacked; } )

# 3. Copy binary package contents that the target firmware lacks. unpack.sh
#    puts the files of every binary package into <package dir>/files-<name>;
#    only directories missing in the target are taken from the donor.
msg "Adding storage modules from the donor"
copied=0
while IFS= read -r -d '' src; do
	rel=${src#"$WORK/sdk-donor/"}
	if [ ! -e "$WORK/sdk/$rel" ]; then
		mkdir -p "$(dirname "$WORK/sdk/$rel")"
		cp -a "$src" "$WORK/sdk/$rel"
		echo "  + $rel"
		copied=$((copied + 1))
	fi
done < <(find "$WORK/sdk-donor/package" -maxdepth 4 -type d -name 'files-*' -print0)
echo "  $copied directories copied"

# 4. Model overlay: Kconfig values and target features.
msg "Applying the $MODEL overlay"
TARGET_DIR=$(find "$WORK/sdk/target/linux" -maxdepth 2 -type d -name "$MODEL" | head -1)
[ -n "$TARGET_DIR" ] || { echo "$MODEL not found in the SDK" >&2; exit 1; }
CFG="$TARGET_DIR/ndwrt.config"
grep -v '^#' "$MODEL_DIR/config.overlay" | grep '=' | while IFS= read -r line; do
	key=${line%%=*}
	if grep -qE "^($key=|# $key is not set)" "$CFG"; then
		sed -i -E "s|^($key=.*\|# $key is not set)\$|$line|" "$CFG"
	else
		echo "$line" >> "$CFG"
	fi
done
if [ -f "$MODEL_DIR/target.mk.append" ] && ! grep -qF -f "$MODEL_DIR/target.mk.append" "$TARGET_DIR/target.mk"; then
	cat "$MODEL_DIR/target.mk.append" >> "$TARGET_DIR/target.mk"
fi

# 5. Patches for the WireGuard kernel module (wg-obfuscator mode via I5).
if ls "$HERE"/package/kernel/wireguard/patches/*.patch >/dev/null 2>&1; then
	msg "Adding WireGuard module patches"
	mkdir -p "$WORK/sdk/package/kernel/wireguard/patches"
	cp "$HERE"/package/kernel/wireguard/patches/*.patch "$WORK/sdk/package/kernel/wireguard/patches/"
fi

# 6. Build.
msg "Building (make -j$JOBS)"
cd "$WORK/sdk"
make -j"$JOBS"
msg "Done:"
ls -1 bin/*/*.bin
