# Thư mục bằng chứng (demo-evidence)

| Thư mục | Nội dung | Cách tạo |
|---|---|---|
| `01-architecture/` | Sơ đồ kiến trúc, luồng request | có sẵn (`architecture.md`) |
| `02-application-api/` | Lệnh gọi API mẫu và kết quả | `scripts\collect-evidence.ps1` |
| `03-docker/` | Danh sách image đã build | `scripts\collect-evidence.ps1` |
| `04-kubernetes/` | Node, workload, requests/limits, giá trị Helm | `scripts\collect-evidence.ps1` |
| `05-hpa/` | Trạng thái HPA, `kubectl top`, bảng replica theo thời gian | `collect-evidence.ps1`, `run-loadtest.ps1` |
| `06-prometheus-grafana/` | **Ảnh chụp dashboard** (chụp tay trong lúc chạy tải) | chụp màn hình Grafana |
| `07-k6-results/` | Mỗi lần chạy một thư mục: `k6-console.txt`, `scaling.csv`, `kubectl-before/after.txt` | `scripts\run-loadtest.ps1` |
| `08-aws-multinode/` | Chỉ tạo nếu thực sự triển khai AWS | thủ công |
| `09-recordings/` | Video quay demo (không đưa lên Git) | thủ công |

Không đưa vào đây: access key, kubeconfig, mật khẩu (`.env`, `.grafana-admin-password` đã nằm trong `.gitignore`).
`summary.json` của k6 bị bỏ qua khỏi Git vì lớn; số liệu chính đã có trong `k6-console.txt`.
