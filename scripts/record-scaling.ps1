# Samples HPA / Pod state every few seconds into a CSV (evidence for the replica-vs-time table in the report).
# Usage: .\scripts\record-scaling.ps1 -OutFile demo-evidence\05-hpa\scaling.csv [-IntervalSec 5] [-DurationSec 900]
param(
  [Parameter(Mandatory)][string]$OutFile,
  [int]$IntervalSec = 5,
  [int]$DurationSec = 900
)
. "$PSScriptRoot\common.ps1"
New-Item -ItemType Directory -Force (Split-Path -Parent $OutFile) | Out-Null
"time,catalogue_cpu_pct,catalogue_target_pct,catalogue_current,catalogue_desired,gateway_cpu_pct,gateway_current,gateway_desired" |
  Out-File $OutFile -Encoding ascii

function Get-Hpa($name) {
  $old = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  $jp = '{.status.currentMetrics[0].resource.current.averageUtilization},{.spec.metrics[0].resource.target.averageUtilization},{.status.currentReplicas},{.status.desiredReplicas}'
  $v = & kubectl -n $Namespace get hpa "$Release-$name" -o "jsonpath=$jp" 2>$null
  $ErrorActionPreference = $old
  return ($v -split ",")
}

$end = (Get-Date).AddSeconds($DurationSec)
while ((Get-Date) -lt $end) {
  $c = Get-Hpa "catalogue"; $g = Get-Hpa "gateway"
  $line = "{0},{1},{2},{3},{4},{5},{6},{7}" -f (Get-Date -Format "HH:mm:ss"), $c[0], $c[1], $c[2], $c[3], $g[0], $g[2], $g[3]
  Add-Content -Path $OutFile -Value $line -Encoding ascii
  Start-Sleep -Seconds $IntervalSec
}
