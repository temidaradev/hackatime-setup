param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$ApiKey,

    [Parameter(Mandatory=$false, Position=1)]
    [string]$ApiUrl
)

$ErrorActionPreference = "Stop"

$Repo = "hackclub/hackatime-setup"
$BinaryName = "hackatime_cli.exe"

$AssetName = "hackatime_setup-windows-x86_64.zip"

$ReleasesUri = "https://api.github.com/repos/$Repo/releases/latest"
$Release = Invoke-RestMethod -Uri $ReleasesUri -Headers @{ "User-Agent" = "PowerShell" }

$Asset = $Release.assets | Where-Object { $_.name -eq $AssetName }
if (-not $Asset) {
    Write-Error "Could not find release asset: $AssetName"
    exit 1
}

$DownloadUrl = $Asset.browser_download_url

$TempDir = Join-Path $env:TEMP "hackatime_setup_$(Get-Random)"
New-Item -ItemType Directory -Path $TempDir | Out-Null
$ZipPath = Join-Path $TempDir $AssetName

try {
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath
    Expand-Archive -Path $ZipPath -DestinationPath $TempDir -Force

    if ($ApiUrl) {
        & (Join-Path $TempDir $BinaryName) --key $ApiKey --api-url $ApiUrl
    } else {
        & (Join-Path $TempDir $BinaryName) --key $ApiKey
    }
}
finally {
    Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue
}
