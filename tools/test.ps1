param ([string]$platform_choice)

$httpbinLog = Join-Path (Get-Location) "httpbin.log"
Remove-Item $httpbinLog -ErrorAction SilentlyContinue
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
    Remove-Job $job
    throw "go-httpbin did not start listening within 5 minutes."
}

Start-Sleep -Seconds 2

$ROOT=$(pwd).Path

function test_build {
    param ([string]$platform)
    try {
        Set-Location "lib\\tests" -ErrorAction Stop
        $process = Start-Process -FilePath "$ROOT\\release\\eli-windows-$platform.exe" -ArgumentList "all.lua" -NoNewWindow -PassThru -ErrorAction Stop
        if (-not $process.WaitForExit(900000)) {
            Stop-Process -Id $process.Id -Force
            throw "test suite timed out after 900 seconds"
        }
        $exitCode = $process.ExitCode
        if ($exitCode -ne 0) { throw "failed" }
    } finally {
        Set-Location "$ROOT"
    }
}

try {
    if ("$platform_choice" -ne "") {
        test_build "$platform_choice"
    } else {
        test_build "x86_64"
        test_build "i686"
    }
} catch {
    Write-Error $_
    exit 333
} finally {
    Stop-Job $job | Out-Null
    Remove-Job $job
}
