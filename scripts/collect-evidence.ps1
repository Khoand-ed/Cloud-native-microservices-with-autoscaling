# Snapshots the current Kubernetes state into demo-evidence/ (text only; no secrets are printed).
. "$PSScriptRoot\common.ps1"

$ev = Join-Path $Root "demo-evidence"
function Save($relPath, [scriptblock]$cmd) {
  $target = Join-Path $ev $relPath
  New-Item -ItemType Directory -Force (Split-Path -Parent $target) | Out-Null
  $old = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  & $cmd 2>&1 | ForEach-Object { "$_" } | Out-File $target -Encoding utf8
  $ErrorActionPreference = $old
  Write-Host "saved $relPath"
}

Save "04-kubernetes\nodes.txt"            { kubectl get nodes -o wide }
Save "04-kubernetes\workloads.txt"        { kubectl -n demo get deploy,sts,svc,pods,pvc -o wide }
Save "04-kubernetes\monitoring-pods.txt"  { kubectl -n monitoring get pods -o wide }
Save "04-kubernetes\resources.txt"        { kubectl -n demo get deploy -o custom-columns="NAME:.metadata.name,REQUESTS:.spec.template.spec.containers[0].resources.requests,LIMITS:.spec.template.spec.containers[0].resources.limits" }
Save "05-hpa\hpa.txt"                     { kubectl -n demo get hpa }
Save "05-hpa\hpa-describe.txt"            { kubectl -n demo describe hpa }
Save "05-hpa\top-nodes.txt"               { kubectl top nodes }
Save "05-hpa\top-pods.txt"                { kubectl top pods -n demo }
Save "03-docker\images.txt"               { docker images --filter "reference=catalogue-service" --filter "reference=api-gateway" }
Save "02-application-api\sample-calls.txt" {
  "GET /api/products?limit=3"; curl.exe -s "http://localhost:8080/api/products?limit=3"
  "`nGET /api/products/1";      curl.exe -s "http://localhost:8080/api/products/1"
}
Copy-Item (Join-Path $Root "charts\catalogue-app\values.yaml") (Join-Path $ev "04-kubernetes\helm-values.yaml") -Force
Write-Host "Done. Add screenshots (Grafana, terminals) by hand into the numbered folders."
