$ROOT=$(pwd).Path

function test_build {
    param ([string]$platform)
    cd "lib\\tests" &&
    & "$ROOT\\release\\eli-win-$platform.exe" "all.lua" &&
    cd "$ROOT" || throw "failed"
}

try {
    test_build "x86_64"
    test_build "i686"
} catch {
    exit 1
}