# Builds the service images and loads them into every kind node (no registry needed locally).
# Third-party images (postgres, prometheus, ...) are pulled by the nodes themselves: `kind load` fails for
# multi-arch images on Docker Desktop's containerd image store ("content digest ... not found").
. "$PSScriptRoot\common.ps1"

Invoke-Native docker build -t "catalogue-service:$ImageTag" "$Root\services\catalogue"
Invoke-Native docker build -t "api-gateway:$ImageTag" "$Root\services\gateway"

foreach ($img in "catalogue-service:$ImageTag", "api-gateway:$ImageTag") {
  Invoke-Native kind load docker-image $img --name $ClusterName
}
