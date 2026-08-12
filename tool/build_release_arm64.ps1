$ErrorActionPreference = "Stop"

Push-Location (Join-Path $PSScriptRoot "..")
try {
    flutter build apk --release --split-per-abi --target-platform android-arm64 --no-pub
}
finally {
    Pop-Location
}
