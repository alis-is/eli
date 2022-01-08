#!/bin/sh

test_build() {
    cd lib/tests && \
    "$ROOT/build/$1-linux-musl-cross/eli" all.lua && \
    echo cp "$ROOT/build/$1-linux-musl-cross/eli" "release/eli-unix-$1" && \
    cp "$ROOT/build/$1-linux-musl-cross/eli" "$ROOT/release/eli-unix-$1"
    cd "$ROOT"
}

test_qemu_build() {
    cd lib/tests && \
    "$2" "$ROOT/build/$1-linux-musl-cross/eli" all.lua && \
    cp "$ROOT/build/$1-linux-musl-cross/eli" "$ROOT/release/eli-unix-$1"
    cd "$ROOT"
}

test_platform() {
    if [ "$PLATFORM" = "$1" ]; then
        test_build "$1"
    elif which qemu-x86_64; then
        test_qemu_build "$1" "qemu-${2:-$1}"
    fi
}