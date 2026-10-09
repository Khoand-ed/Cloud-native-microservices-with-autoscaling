# Kịch bản quay demo (cluster kind 3 node, local)

Thời lượng gợi ý: 10–12 phút. Mọi lệnh đều đã được thử trước; **không chạy lệnh nào chưa tổng duyệt**.

## 0. Chuẩn bị (làm trước khi bấm quay, không đưa vào video)

```powershell
cd "D:\VII\NT533\Đồ án"
. .\scripts\env.ps1                 # nạp kind/helm/k6 vào PATH của terminal này
.\scripts\up.ps1                    # nếu cluster chưa có (~5–8 phút lần đầu); bỏ qua nếu đã chạy
kubectl get nodes                   # 3 node Ready
kubectl -n demo get pods            # tất cả Running 1/1; HPA 1 replica
k6 run load-tests/smoke.js          # phải xanh hết
```

Bố trí màn hình (4 cửa sổ, chữ lớn, ẩn thông báo/tab cá nhân):

| Vị trí | Nội dung |
|---|---|
| Trái-trên | Terminal A: `kubectl -n demo get hpa -w` |
| Trái-dưới | Terminal B: `kubectl -n demo get pods -o wide -w` |
| Phải | Trình duyệt: Grafana `http://localhost:3000/d/autoscale-demo` (khoảng thời gian *Last 15 minutes*, refresh 5s) |
| Terminal C (dùng để gõ lệnh) | chạy k6 |

Không mở trang Grafana admin / file `.grafana-admin-password` / kubeconfig trong khung hình.

## 1. Giới thiệu kiến trúc (~1 phút)

Mở `demo-evidence/01-architecture` (hoặc README) và nói: *Client → API Gateway → Catalogue Service → PostgreSQL*; HPA theo CPU trên Gateway và Catalogue; Prometheus + Grafana giám sát; k6 tạo tải.

## 2. Hiện trạng hệ thống (~2 phút)

```powershell
kubectl get nodes -o wide
kubectl -n demo get deploy,sts,svc,pods -o wide
kubectl -n demo get hpa
kubectl -n demo describe hpa shop-catalogue      # target 50%, min 1, max 6
kubectl -n demo get deploy shop-catalogue -o jsonpath="{.spec.template.spec.containers[0].resources}"
```

Chỉ ra: Pod phân bố trên các worker, `requests/limits`, PVC của PostgreSQL (`kubectl -n demo get pvc`).

Chứng minh luồng ứng dụng:

```powershell
curl.exe "http://localhost:8080/api/products?limit=3"
curl.exe "http://localhost:8080/api/products/1"
```

## 3. Dashboard trước tải (~1 phút)

Chuyển sang Grafana: replicas = 1, CPU thấp, request rate ≈ 0. Giải thích từng panel (đường đỏ 50% là ngưỡng HPA).

## 4. Tạo tải và quan sát scale-out (~5 phút)

Terminal C:

```powershell
k6 run load-tests/hpa-ramp.js
```

Kịch bản k6 (mặc định ~11 phút): 30s nền → 1 phút tăng → 4 phút giữ đỉnh → giảm → 4 phút tải thấp.
Khi quay có thể dùng `HOLD=3m COOLDOWN=3m` để rút gọn:

```powershell
$env:HOLD="3m"; $env:COOLDOWN="3m"; k6 run load-tests/hpa-ramp.js
```

Vừa chạy vừa chỉ cho người xem:
1. Terminal A: `TARGETS` của HPA vượt 50% → `REPLICAS` tăng (HPA chỉ phản ứng sau ~15–30s lấy metrics).
2. Terminal B: Pod mới `Pending → ContainerCreating → Running`, rải trên các node.
3. Grafana: CPU %, request rate tăng, replicas desired/current tăng; latency p95 giảm sau khi có thêm Pod.

## 5. Scale-in (~3 phút, có thể cắt/tua trong video)

Sau khi tải giảm, CPU % xuống dưới ngưỡng; sau `scaleDownStabilizationSeconds` (60s ở chart này, mặc định k8s là 300s) replicas giảm dần về 1. Nhấn mạnh scale-down chậm hơn scale-up là chủ ý để tránh dao động (flapping).

## 6. Kết thúc (~1 phút)

- Mở `demo-evidence/07-k6-results/<lần chạy>/` và `demo-evidence/05-hpa/` (bảng replica theo thời gian).
- Tóm tắt: thời gian phản ứng, số replica tối đa, p95, tỷ lệ lỗi, bài học.

## Phương án dự phòng

| Sự cố | Cách xử lý |
|---|---|
| HPA hiện `<unknown>` | `kubectl top pods -A`; đợi 1 phút; nếu vẫn lỗi: `kubectl -n kube-system rollout restart deploy/metrics-server` |
| Không scale | Tăng tải: `$env:PEAK_VUS="100"; $env:STRESS_MS="40"` rồi chạy lại k6 |
| Pod `Pending` | `kubectl describe pod` — thiếu CPU của Docker Desktop (tăng CPU/RAM trong Settings → Resources) |
| Grafana trống | Mở Prometheus `http://localhost:9090/targets`, kiểm tra 2 target `shop-*` là `UP`; đổi khoảng thời gian dashboard |
| Cluster hỏng | `.\scripts\down.ps1; .\scripts\up.ps1` (cần ~8 phút) — nên có video/ảnh/log đã lưu làm dự phòng |
| Mất mạng | Image app đã nạp sẵn vào node; Prometheus/Grafana đã chạy nên không cần mạng |

## Sau khi quay

```powershell
.\scripts\collect-evidence.ps1          # chụp trạng thái kubectl vào demo-evidence/
.\scripts\down.ps1                      # (tuỳ chọn) xoá cluster để giải phóng RAM/CPU
```
