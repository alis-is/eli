#!/bin/sh

podman build -t elibuild .
podman run -v "$(pwd):/root/luabuild" -v "$(pwd)/toolchains:/opt/cross" -e TOOLCHAINS='x86_64-linux-musl-cross;i686-linux-musl-cross;aarch64-linux-musl-cross' elibuild

PLATFORM=$(uname -m)
ROOT=$(pwd)
rm -rf release
rm -rf .meta
mkdir release

. "./test-utils.sh"

mkdir -p "$ROOT/release"
test_platform "x86_64" && cp "$ROOT/build/x86_64-linux-musl-cross/eli" "$ROOT/release/eli-unix-x86_64"
test_platform "i686" "i386" && cp "$ROOT/build/i686-linux-musl-cross/eli" "$ROOT/release/eli-unix-i686"
test_platform "aarch64" && cp "$ROOT/build/aarch64-linux-musl-cross/eli" "$ROOT/release/eli-unix-aarch64"
"$ROOT/build/$PLATFORM-linux-musl-cross/eli" "$ROOT/tools/meta-generator.lua" && zip release/meta.zip -r .meta/* && rm -r .meta