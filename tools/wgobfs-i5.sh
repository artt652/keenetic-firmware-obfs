#!/bin/sh
# Builds the AmneziaWG I5 value that switches the patched Keenetic WireGuard
# module into wg-obfuscator mode. See docs/i5-format.md.
#
#   tools/wgobfs-i5.sh <key> [NONE|STUN] [max-dummy]
#
# Prints e.g.  <b 0x57474F42010100046A6E44...>
set -eu

usage() { echo "usage: $0 <key> [NONE|STUN] [max-dummy 0..1024]" >&2; exit 2; }
[ $# -ge 1 ] || usage
KEY=$1
MASKING=$(printf '%s' "${2:-STUN}" | tr '[:lower:]' '[:upper:]')
DUMMY=${3:-4}

len=$(printf '%s' "$KEY" | wc -c | tr -d ' ')
[ "$len" -ge 1 ] && [ "$len" -le 255 ] || { echo "key must be 1..255 bytes" >&2; exit 1; }
case "$KEY" in *'#'*|*'='*) echo "key must not contain # or =" >&2; exit 1 ;; esac
case "$MASKING" in NONE) M=00 ;; STUN) M=01 ;; *) echo "masking: NONE or STUN" >&2; exit 1 ;; esac
case "$DUMMY" in ''|*[!0-9]*) echo "max-dummy: 0..1024" >&2; exit 1 ;; esac
[ "$DUMMY" -le 1024 ] || { echo "max-dummy: 0..1024" >&2; exit 1; }

MAGIC=57474F42   # "WGOB"
VERSION=01
D=$(printf '%04X' "$DUMMY")
K=$(printf '%s' "$KEY" | od -An -tx1 -v | tr -d ' \n' | tr '[:lower:]' '[:upper:]')
printf '<b 0x%s%s%s%s%s>\n' "$MAGIC" "$VERSION" "$M" "$D" "$K"
