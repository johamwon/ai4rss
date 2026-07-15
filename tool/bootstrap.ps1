$ErrorActionPreference = 'Stop'

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter SDK is required and must be available on PATH.'
}

$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
  flutter create `
    --project-name river_app `
    --platforms android,ios,windows `
    apps/river_app
  flutter pub get
  dart format .
  dart run tool/ci.dart fast
}
finally {
  Pop-Location
}
