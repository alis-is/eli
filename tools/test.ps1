param ([string]$platform_choice)

$httpbinLog = "$PSScriptRoot\httpbin.log"
$job = Start-Job -ScriptBlock {
    go run github.com/mccutchen/go-httpbin/v2/cmd/go-httpbin@v2 -host 127.0.0.1 -port 8081 *>&1 | Tee-Object -FilePath $using:httpbinLog
}

$timeout = 300 # 5 minutes in seconds
$elapsed = 0
$interval = 2

while ($elapsed -lt $timeout) {
    if (Test-Path $httpbinLog -PathType Leaf) {
        $content = Get-Content $httpbinLog -Raw
        if ($content -match "Listening on") {
            break
        }
    }
    Start-Sleep -Seconds $interval
    $elapsed += $interval
}

if ($elapsed -ge $timeout) {
    Stop-Job $job | Out-Null
    throw "go-httpbin did not start listening within 5 minutes."
}

Start-Sleep -Seconds 2

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