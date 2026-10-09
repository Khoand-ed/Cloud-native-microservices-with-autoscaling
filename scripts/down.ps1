# Deletes the local kind cluster (and everything inside it, including the DB volume).
. "$PSScriptRoot\common.ps1"
if (Test-Cluster) { Invoke-Native kind delete cluster --name $ClusterName } else { Write-Host "no cluster to delete" }
