#!/bin/sh

# for debugging
# set -euxo

go run github.com/mccutchen/go-httpbin/v2/cmd/go-httpbin@v2 -host 127.0.0.1 -port 8081 >httpbin.log 2>&1 &
HTTPBIN_PID=$!

# Wait up to 5 minutes (300 seconds) for "go-httpbin listening" to appear in httpbin.log
TIMEOUT=300
SECONDS_WAITED=0
while ! grep -q "go-httpbin listening" httpbin.log; do
    sleep 1
    SECONDS_WAITED=$((SECONDS_WAITED + 1))
    if [ $SECONDS_WAITED -ge $TIMEOUT ]; then
        echo "Timeout waiting for go-httpbin to start."
        kill $HTTPBIN_PID 2>/dev/null
        exit 1
    fi
done

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
