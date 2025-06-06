param ([string]$platform_choice)

Start-Job { go run github.com/mccutchen/go-httpbin/v2/cmd/go-httpbin@v2 -host 127.0.0.1 -port 8081 }

$ROOT=$(pwd).Path

function test_build {
    param ([string]$platform)
    Set-Location "lib\\tests" &&
    & "$ROOT\\release\\eli-windows-$platform.exe" "all.lua" &&
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