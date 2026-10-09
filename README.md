# Cloud-native Microservices with Autoscaling

Đồ án NT533: hệ thống microservices triển khai trên Kubernetes, tự co giãn bằng **HPA (CPU)**, giám sát bằng **Prometheus + Grafana**, kiểm thử tải bằng **k6**.

```
            ┌──────────┐   ┌───────────────────┐   ┌─────────────────────┐   ┌──────────────┐
 k6 / curl ─►│ NodePort │──►│ API Gateway (x1-4)│──►│ Catalogue Svc (x1-6)│──►│ PostgreSQL   │
  :8080      │  30080   │   │  FastAPI + HPA    │   │  FastAPI + HPA      │   │ StatefulSet  │
             └──────────┘   └───────────────────┘   └─────────────────────┘   │ + PVC (1Gi)  │
                                   │ /metrics                │ /metrics        └──────────────┘
                                   └──────────► Prometheus ◄─┘ ──► Grafana (dashboard "Autoscaling Demo")
```

Kế hoạch chuẩn bị gốc: [docs/ke-hoach-tai-nguyen-demo-cloud-native-autoscaling.md](docs/ke-hoach-tai-nguyen-demo-cloud-native-autoscaling.md) ·
Kịch bản quay: [docs/kich-ban-demo.md](docs/kich-ban-demo.md)

## Công nghệ đã chọn

| Thành phần | Lựa chọn |
|---|---|
| Backend | Python 3.12 + FastAPI (1 uvicorn worker / Pod để CPU tỉ lệ với số Pod) |
| Database | PostgreSQL 16, StatefulSet 1 replica + PersistentVolumeClaim, seed 100 sản phẩm bằng `init.sql` |
| Kubernetes local | **kind** — 1 control-plane + 2 worker (multi-node) trên Docker Desktop |
| Đóng gói / triển khai | Dockerfile, `docker-compose.yml` (chạy không cần K8s), **Helm chart** `charts/catalogue-app` |
| Autoscaling | metrics-server + HPA `autoscaling/v2` theo CPU utilization (% của `requests`) |
| Monitoring | kube-prometheus-stack (Prometheus, Grafana, kube-state-metrics), ServiceMonitor cho 2 service |
| Load test | k6 |

## Cấu trúc thư mục

```
services/catalogue, services/gateway   mã nguồn + Dockerfile
charts/catalogue-app                   Helm chart (Deployment, Service, StatefulSet, HPA, Secret, ServiceMonitor)
k8s/kind-cluster.yaml                  cấu hình cluster kind 3 node + port mapping
monitoring/                            values kube-prometheus-stack + dashboard Grafana (JSON)
load-tests/                            kịch bản k6 (smoke.js, hpa-ramp.js)
scripts/                               tự động hoá: cài công cụ, dựng cluster, build, monitoring, deploy, ghi bằng chứng
demo-evidence/                         bằng chứng cho báo cáo (kubectl, HPA, k6, ảnh, video)
docs/                                  kế hoạch + kịch bản demo
```

## Yêu cầu máy

Windows 10/11 + Docker Desktop (khuyến nghị ≥ 8 GB RAM, ≥ 4 CPU cấp cho Docker), Git, PowerShell, `kubectl` (đi kèm Docker Desktop).
`kind`, `helm`, `k6` được tải vào `tools/` (không cần quyền admin, không sửa PATH hệ thống):

```powershell
.\scripts\setup-tools.ps1     # chỉ chạy lần đầu (nếu thư mục tools/ chưa có)
. .\scripts\env.ps1           # chạy trong MỖI terminal mới để nạp kind/helm/k6 vào PATH
```

## Dựng toàn bộ môi trường (một lệnh)

```powershell
.\scripts\up.ps1
```

Tương đương các bước: `01-cluster` (kind + metrics-server) → `02-build-load` (build & nạp image) → `03-monitoring` → `04-deploy-app`. Kết quả:

| Dịch vụ | URL |
|---|---|
| API Gateway | http://localhost:8080/api/products |
| Grafana (xem ẩn danh, chỉ đọc) | http://localhost:3000/d/autoscale-demo |
| Prometheus | http://localhost:9090 |

Mật khẩu admin Grafana được sinh ngẫu nhiên và lưu ở `.grafana-admin-password` (không đưa lên Git).
Mật khẩu PostgreSQL được Helm sinh ngẫu nhiên khi cài lần đầu và giữ nguyên khi `helm upgrade`.

## Chạy nhanh không cần Kubernetes

```powershell
copy .env.example .env      # đặt POSTGRES_PASSWORD
docker compose up --build   # gateway: http://localhost:8080
```

## API

| Method | Đường dẫn (qua Gateway) | Mô tả |
|---|---|---|
| GET | `/api/products?category=&limit=&offset=` | Danh sách sản phẩm |
| GET | `/api/products/{id}` | Chi tiết (404 nếu không có) |
| POST | `/api/products` | Thêm sản phẩm (409 nếu trùng SKU) |
| GET | `/api/stress?ms=25` | Đốt CPU ~`ms` mili-giây ở Catalogue — tín hiệu tải có kiểm soát cho HPA |
| GET | `/healthz`, `/readyz`, `/metrics` | Liveness, readiness, Prometheus |

## Kiểm thử tải

```powershell
k6 run load-tests/smoke.js                      # kiểm tra nhanh 10 giây
.\scripts\run-loadtest.ps1 -Label demo1         # tải đầy đủ + ghi replica theo thời gian + lưu bằng chứng
```

Tham số k6 (biến môi trường): `PEAK_VUS`, `STRESS_MS`, `HOLD`, `COOLDOWN`, `BASE_URL`.
Kết quả lưu tại `demo-evidence/07-k6-results/<thời-gian>-<nhãn>/` (console, summary, `scaling.csv`, kubectl trước/sau).

## Dọn dẹp

```powershell
.\scripts\down.ps1        # xoá cluster kind (kể cả dữ liệu DB)
```

## Về AWS multi-node

Repo hiện chạy **local-first** (kind 3 node) theo khuyến nghị của kế hoạch để không phát sinh chi phí.
Chart dùng image/registry có thể cấu hình (`gateway.image.*`, `catalogue.image.*`) nên có thể triển khai lên cluster AWS mà không đổi code;
phần AWS chỉ nên dựng khi giảng viên yêu cầu bằng chứng cloud — xem mục 7 của kế hoạch về kiểm soát chi phí.
