#!/bin/sh

# for debugging
# set -euxo

PLATFORM=$(uname -m)
ROOT=$(pwd)

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

    TEST_PLATFORM=$1
    # if platfrom arm64 rename to aarch64
    if [ "$PLATFORM" = "arm64" ]; then
        PLATFORM="aarch64"
    fi
    if [ "$TEST_PLATFORM" = "arm64" ]; then
        TEST_PLATFORM="aarch64"
    fi

    if [ "$PLATFORM" = "$TEST_PLATFORM" ]; then
        test_build "$TEST_PLATFORM" "$OS"
    elif which qemu-x86_64; then
        test_qemu_build "$TEST_PLATFORM" "$OS" "qemu-${2:-$TEST_PLATFORM}"
    fi
}

if [ -n "$1" ]; then
    test_platform "$1"
else
    test_platform "x86_64"
    test_platform "i686" "i386"
    test_platform "aarch64"
fi
