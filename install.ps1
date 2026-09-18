param(
    [switch]$Prerelease
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$procArch = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
$arch = switch ($procArch) {
    "AMD64" { "x86_64" }
    "ARM64" { "aarch64" }
    default { throw "Unsupported architecture: $procArch" }
}

$api = if ($Prerelease) {
    "https://api.github.com/repos/alis-is/eli/releases"
} else {
    "https://api.github.com/repos/alis-is/eli/releases/latest"
}
$release = Invoke-RestMethod $api
if ($Prerelease) { $release = $release | Select-Object -First 1 }
$version = $release.tag_name

$installed = Get-Command eli -ErrorAction SilentlyContinue
if ($installed -and (eli -v 2>$null) -match [regex]::Escape($version)) {
    Write-Host "latest eli already available"
    exit 0
}

$destination = Join-Path $env:LOCALAPPDATA "eli"
$binary = Join-Path $destination "eli.exe"
New-Item -ItemType Directory -Force -Path $destination | Out-Null

$url = "https://github.com/alis-is/eli/releases/download/$version/eli-windows-$arch.exe"
Write-Host "downloading eli-windows-$arch $version..."
Invoke-WebRequest -Uri $url -OutFile $binary -UseBasicParsing

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (($userPath -split ";") -notcontains $destination) {
    $newPath = if ([string]::IsNullOrEmpty($userPath)) { $destination } else { "$userPath;$destination" }
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    $env:Path = "$env:Path;$destination"
}

Write-Host "eli $version for windows-$arch successfully installed to $binary"
