# Runs a k6 script, records scaling in parallel and stores everything under demo-evidence/.
# Usage: .\scripts\run-loadtest.ps1 [-Script load-tests\hpa-ramp.js] [-Label run1] [-Env @{PEAK_VUS="60"}]
param(
  [string]$Script = "load-tests\hpa-ramp.js",
  [string]$Label = "run",
  [hashtable]$Env = @{}
)
. "$PSScriptRoot\common.ps1"

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$k6Dir  = Join-Path $Root "demo-evidence\07-k6-results\$stamp-$Label"
$hpaDir = Join-Path $Root "demo-evidence\05-hpa"
New-Item -ItemType Directory -Force $k6Dir, $hpaDir | Out-Null

foreach ($k in $Env.Keys) { Set-Item "env:$k" $Env[$k] }
$env:SUMMARY_FILE = Join-Path $k6Dir "summary.json"

# Before-state snapshot.
& kubectl -n $Namespace get "deploy,hpa,pods" -o wide 2>&1 | Out-File (Join-Path $k6Dir "kubectl-before.txt") -Encoding utf8

# Background recorder (long enough for the default hpa-ramp.js, which runs ~11 minutes).
$rec = Start-Job -ScriptBlock {
  param($ps1, $out) & powershell -NoProfile -File $ps1 -OutFile $out -IntervalSec 5 -DurationSec 1500
} -ArgumentList "$PSScriptRoot\record-scaling.ps1", (Join-Path $k6Dir "scaling.csv")

try {
  $old = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  & k6 run --quiet (Join-Path $Root $Script) 2>&1 | Tee-Object -FilePath (Join-Path $k6Dir "k6-console.txt")
  $ErrorActionPreference = $old
} finally {
  Stop-Job $rec -ErrorAction SilentlyContinue; Remove-Job $rec -Force -ErrorAction SilentlyContinue
}

& kubectl -n $Namespace get "deploy,hpa,pods" -o wide 2>&1 | Out-File (Join-Path $k6Dir "kubectl-after.txt") -Encoding utf8
Write-Host "Evidence saved in $k6Dir"
