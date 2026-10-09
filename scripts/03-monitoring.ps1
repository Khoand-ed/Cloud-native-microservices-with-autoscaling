# Installs kube-prometheus-stack (Prometheus + Grafana) and the Autoscaling Demo dashboard.
. "$PSScriptRoot\common.ps1"

$MonNs = "monitoring"
Invoke-Native helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
Invoke-Native helm repo update prometheus-community

# Random Grafana admin password, kept out of git. Anonymous read-only access is enabled for the demo.
$pwFile = Join-Path $Root ".grafana-admin-password"
if (-not (Test-Path $pwFile)) {
  $chars = (48..57) + (65..90) + (97..122)
  $pw = -join ($chars | Get-Random -Count 20 | ForEach-Object { [char]$_ })
  Set-Content -Path $pwFile -Value $pw -NoNewline -Encoding ascii
}
$adminPw = Get-Content $pwFile -Raw

Invoke-Native helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack `
  --namespace $MonNs --create-namespace `
  -f "$Root\monitoring\kube-prometheus-stack-values.yaml" `
  --set "grafana.adminPassword=$adminPw" --wait --timeout 10m

# Dashboard is picked up by the Grafana sidecar via the grafana_dashboard label.
Invoke-Native kubectl -n $MonNs create configmap autoscaling-demo-dashboard `
  --from-file="autoscaling-demo.json=$Root\monitoring\dashboards\autoscaling-demo.json" `
  --dry-run=client -o yaml | Out-File "$env:TEMP\dash-cm.yaml" -Encoding ascii
Invoke-Native kubectl -n $MonNs apply -f "$env:TEMP\dash-cm.yaml"
Invoke-Native kubectl -n $MonNs label configmap autoscaling-demo-dashboard grafana_dashboard=1 --overwrite

Invoke-Native kubectl -n $MonNs get pods
Write-Host "Grafana:    http://localhost:3000/d/autoscale-demo   (anonymous viewer; admin password in .grafana-admin-password)"
Write-Host "Prometheus: http://localhost:9090"
