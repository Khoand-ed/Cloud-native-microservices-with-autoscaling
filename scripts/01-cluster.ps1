# Creates the multi-node kind cluster and installs metrics-server (required by the HPA).
. "$PSScriptRoot\common.ps1"

if (Test-Cluster) {
  Write-Host "kind cluster '$ClusterName' already exists - skipping create"
} else {
  Invoke-Native kind create cluster --config "$Root\k8s\kind-cluster.yaml" --wait 120s
}
Invoke-Native kubectl config use-context $KubeContext

Invoke-Native helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ --force-update
Invoke-Native helm repo update metrics-server
# kind kubelets use self-signed certs, hence --kubelet-insecure-tls (local cluster only).
Invoke-Native helm upgrade --install metrics-server metrics-server/metrics-server `
  --namespace kube-system --set "args={--kubelet-insecure-tls}" --wait --timeout 3m

Invoke-Native kubectl get nodes -o wide
Write-Host "Cluster ready. Try: kubectl top nodes (metrics may take ~1 minute to appear)"
