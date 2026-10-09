# One-shot bring-up of the whole local environment (idempotent; safe to re-run).
# Order matters: cluster + metrics-server -> images -> monitoring (installs ServiceMonitor CRD) -> app.
. "$PSScriptRoot\common.ps1"

& "$PSScriptRoot\01-cluster.ps1"
& "$PSScriptRoot\02-build-load.ps1"
& "$PSScriptRoot\03-monitoring.ps1"
& "$PSScriptRoot\04-deploy-app.ps1"

Write-Host ""
Write-Host "Everything is up."
Write-Host "  API:        http://localhost:8080/api/products"
Write-Host "  Grafana:    http://localhost:3000/d/autoscale-demo"
Write-Host "  Prometheus: http://localhost:9090"
Write-Host "Next: k6 run load-tests/smoke.js"
