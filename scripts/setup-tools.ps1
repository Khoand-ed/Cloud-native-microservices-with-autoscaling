# Downloads kind, helm and k6 into ./tools (git-ignored). Used because winget may be unavailable.
# Usage: .\scripts\setup-tools.ps1
$ErrorActionPreference = "Stop"
$root  = Split-Path -Parent $PSScriptRoot
$tools = Join-Path $root "tools"
New-Item -ItemType Directory -Force $tools | Out-Null

$kindVer = "v0.33.0"; $helmVer = "v3.22.0"; $k6Ver = "v2.3.0"
$tmp = Join-Path $env:TEMP "autoscale-tools"; New-Item -ItemType Directory -Force $tmp | Out-Null

if (-not (Test-Path "$tools\kind.exe")) {
  Invoke-WebRequest "https://kind.sigs.k8s.io/dl/$kindVer/kind-windows-amd64" -OutFile "$tools\kind.exe"
}
if (-not (Test-Path "$tools\helm.exe")) {
  Invoke-WebRequest "https://get.helm.sh/helm-$helmVer-windows-amd64.zip" -OutFile "$tmp\helm.zip"
  Expand-Archive "$tmp\helm.zip" $tmp -Force
  Copy-Item "$tmp\windows-amd64\helm.exe" $tools
}
if (-not (Test-Path "$tools\k6.exe")) {
  Invoke-WebRequest "https://github.com/grafana/k6/releases/download/$k6Ver/k6-$k6Ver-windows-amd64.zip" -OutFile "$tmp\k6.zip"
  Expand-Archive "$tmp\k6.zip" $tmp -Force
  Copy-Item "$tmp\k6-$k6Ver-windows-amd64\k6.exe" $tools
}
& "$tools\kind.exe" version
& "$tools\helm.exe" version --short
& "$tools\k6.exe" version
