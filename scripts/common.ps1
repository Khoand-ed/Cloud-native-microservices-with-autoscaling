# Shared helpers, dot-sourced by the other scripts.
$ErrorActionPreference = "Stop"
$script:Root = Split-Path -Parent $PSScriptRoot
$env:PATH = "$script:Root\tools;$env:PATH"

$script:ClusterName = "autoscale-demo"
$script:KubeContext = "kind-$script:ClusterName"
$script:Namespace   = "demo"
$script:Release     = "shop"
$script:ImageTag    = "0.1.0"

function Invoke-Native {
  # Run a native command (first arg) and fail loudly on a non-zero exit code.
  # Deliberately a simple function (not [CmdletBinding]) so flags like -o / --name pass through untouched.
  $exe = $args[0]
  $rest = @($args | Select-Object -Skip 1)
  # kind/helm/docker write progress to stderr; PowerShell 5.1 would turn that into a terminating error.
  $old = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  & $exe @rest 2>&1 | ForEach-Object { "$_" }
  $code = $LASTEXITCODE
  $ErrorActionPreference = $old
  if ($code -ne 0) { throw "'$exe $($rest -join ' ')' failed with exit code $code" }
}

function Test-Cluster {
  # kind prints "No kind clusters found." on stderr, which PowerShell 5.1 treats as an error under 'Stop'.
  $old = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  $names = & kind get clusters 2>$null
  $ErrorActionPreference = $old
  return ($names -contains $script:ClusterName)
}
