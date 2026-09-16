#!/bin/sh

# for debugging
# set -euxo

if command -v go-httpbin >/dev/null 2>&1; then
    go-httpbin -host 127.0.0.1 -port 8081 >httpbin.log 2>&1 &
else
    go run github.com/mccutchen/go-httpbin/v2/cmd/go-httpbin@v2 -host 127.0.0.1 -port 8081 >httpbin.log 2>&1 &
fi
HTTPBIN_PID=$!

# Wait up to 5 minutes (300 seconds) for "go-httpbin listening" to appear in httpbin.log
TIMEOUT=300
SECONDS_WAITED=0
while ! grep -q "go-httpbin listening" httpbin.log; do
    sleep 1
    SECONDS_WAITED=$((SECONDS_WAITED + 1))
    if [ $SECONDS_WAITED -ge $TIMEOUT ]; then
        echo "Timeout waiting for go-httpbin to start."
        cat httpbin.log
        kill $HTTPBIN_PID 2>/dev/null
        exit 1
    fi
done

PLATFORM=$(uname -m)
ROOT=$(pwd)

echo "Platform: $PLATFORM"
echo "Root: $ROOT"

run_suite() {
    # Watchdog: a blocked channel/worker test must fail instead of hanging CI.
    if command -v timeout >/dev/null 2>&1; then
        # A suite that handles or defers SIGTERM must still die; kill -9 after 10s.
        timeout -k 10 900 "$@"
        return $?
    fi
    # ponytail: stock macOS lacks timeout(1); same 900s deadline, TERM then KILL.
    "$@" &
    _suite_pid=$!
    _waited=0
    while kill -0 "$_suite_pid" 2>/dev/null; do
        if [ "$_waited" -ge 900 ]; then
            kill -TERM "$_suite_pid" 2>/dev/null
            sleep 10
            kill -KILL "$_suite_pid" 2>/dev/null
            wait "$_suite_pid"
            return 124
        fi
        sleep 1
        _waited=$((_waited + 1))
    done
    wait "$_suite_pid"
}

test_build() {

    cd lib/tests &&
        chmod +x "$ROOT/release/eli-$2-$1" &&
        run_suite "$ROOT/release/eli-$2-$1" all.lua &&
        cd "$ROOT" || exit 1
}

test_qemu_build() {
    cd lib/tests &&
        export QEMU="$3" &&
        chmod +x "$ROOT/release/eli-$2-$1" &&
        run_suite "$3" "$ROOT/release/eli-$2-$1" all.lua &&
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
