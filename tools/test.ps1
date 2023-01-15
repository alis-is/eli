param ([string]$platform_choice)

$ROOT=$(pwd).Path

function test_build {
    param ([string]$platform)
    Set-Location "lib\\tests" &&
    & "$ROOT\\release\\eli-win-$platform.exe" "all.lua" &&
    Set-Location "$ROOT" || throw "failed"
}

try {
    if ("$platform_choice" -ne "") {
        test_build "$platform_choice"
    } else {
        test_build "x86_64"
        test_build "i686"
    }
} catch {
    exit 333
}