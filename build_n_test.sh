#!/bin/sh

podman build -t elibuild .
podman run -v "$(pwd):/root/luabuild" -v "$(pwd)/toolchains:/opt/cross" -e TOOLCHAINS='x86_64-linux-musl-cross;i686-linux-musl-cross;aarch64-linux-musl-cross' elibuild

PLATFORM=$(uname -m)
ROOT=$(pwd)
rm -rf release
rm -rf .meta
mkdir release

test_build() {
    cd lib/tests && \
    "$ROOT/build/$1-linux-musl-cross/eli" all.lua && \
    echo cp "$ROOT/build/$1-linux-musl-cross/eli" "release/eli-unix-$1" && \
    cp "$ROOT/build/$1-linux-musl-cross/eli" "$ROOT/release/eli-unix-$1"
    if [ -f "$ROOT/release/eli-unix-$1" ]; then
       cd "$ROOT" && \
       "$ROOT/release/eli-unix-$1" "$ROOT/tools/meta-generator.lua"
       cd "$ROOT/.meta" && \
       zip "$ROOT/release/meta.zip" -r *
    fi
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

mkdir -p "$ROOT/release"
test_platform "x86_64" && cp "$ROOT/build/x86_64-linux-musl-cross/eli" "$ROOT/release/eli-unix-x86_64"
test_platform "i686" "i386" && cp "$ROOT/build/i686-linux-musl-cross/eli" "$ROOT/release/eli-unix-i686"
test_platform "aarch64" && cp "$ROOT/build/aarch64-linux-musl-cross/eli" "$ROOT/release/eli-unix-aarch64"
"$ROOT/build/$PLATFORM-linux-musl-cross/eli" "$ROOT/tools/meta-generator.lua" && zip release/meta.zip -r .meta/* && rm -r .meta