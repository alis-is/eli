#!/bin/sh

PLATFORM=$(uname -m)
ROOT=$(pwd)

# if platfrom arm64 rename to aarch64
if [ "$PLATFORM" = "arm64" ]; then
    PLATFORM="aarch64"
fi

echo "Platform: $PLATFORM"
echo "Root: $ROOT"

test_build() {
    cd lib/tests &&
        chmod +x "$ROOT/release/eli-$2-$1" &&
        "$ROOT/release/eli-$2-$1" all.lua &&
        cd "$ROOT" || exit 1
}

test_qemu_build() {
    cd lib/tests &&
        export QEMU="$3" &&
        chmod +x "$ROOT/release/eli-$2-$1" &&
        "$3" "$ROOT/release/eli-$2-$1" all.lua &&
        cd "$ROOT" || exit 1
}

test_platform() {
    export OS="linux"
    if [ "$(uname)" = "Darwin" ]; then
        export OS="macos"
    fi
    if [ "$PLATFORM" = "$1" ]; then
        test_build "$1" "$OS"
    elif which qemu-x86_64; then
        test_qemu_build "$1" "$OS" "qemu-${2:-$1}"
    fi
}

if [ -n "$1" ]; then
    test_platform "$1"
else
    test_platform "x86_64"
    test_platform "i686" "i386"
    test_platform "aarch64"
fi
