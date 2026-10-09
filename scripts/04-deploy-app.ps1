# Deploys (or upgrades) the application chart into the demo namespace.
param([switch]$NoServiceMonitor)
. "$PSScriptRoot\common.ps1"

$extra = @()
if ($NoServiceMonitor) { $extra += @("--set", "monitoring.serviceMonitor.enabled=false") }

Invoke-Native helm upgrade --install $Release "$Root\charts\catalogue-app" `
  --namespace $Namespace --create-namespace --reset-values --wait --timeout 5m @extra

Invoke-Native kubectl -n $Namespace get "deploy,sts,svc,pods,hpa"
Write-Host "Gateway: http://localhost:8080/api/products"
