#!/bin/sh

PLATFORM=$(uname -m)
ROOT=$(pwd)

test_build() {
    cd lib/tests && \
    "$ROOT/release/eli-unix-$1" all.lua && \
    cd "$ROOT" || exit 1
}

test_qemu_build() {
    cd lib/tests && \
    export QEMU="$2" && \
    "$2" "$ROOT/release/eli-unix-$1" all.lua && \
    cd "$ROOT" || exit 1
}

test_platform() {
    if [ "$PLATFORM" = "$1" ]; then
        test_build "$1"
    elif which qemu-x86_64; then
        test_qemu_build "$1" "qemu-${2:-$1}"
    fi
}

chmod +x ./release/eli-unix-*
if [ -n "$1" ]; then
    test_platform "$1"
else
    test_platform "x86_64"
    test_platform "i686" "i386"
    test_platform "aarch64"
fi