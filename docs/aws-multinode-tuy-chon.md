# Triển khai AWS multi-node (tuỳ chọn, chỉ làm khi giảng viên yêu cầu)

> Repo **không** tạo bất kỳ tài nguyên AWS nào. Tài liệu này chỉ chuẩn bị đường đi để khi cần có thể dựng nhanh, ngắn hạn và kiểm soát chi phí.
> Hãy xác nhận với giảng viên trước (mục 9 của kế hoạch): có bắt buộc **quay trực tiếp** trên AWS multi-node, hay chỉ cần bằng chứng triển khai?

## Hai hướng, ưu/nhược

| Hướng | Ưu | Nhược / chi phí |
|---|---|---|
| **EKS** (managed) | Ít vận hành; chuẩn ngành | Control plane tính phí theo giờ **không nằm trong free tier**; thêm node EC2, EBS, Load Balancer, NAT Gateway |
| **EC2 + k3s/kubeadm** (tự dựng, 2–3 instance) | Rẻ nhất khi chỉ chạy vài giờ; hiểu rõ từng thành phần | Tự cài/bảo trì; vẫn tính phí EC2/EBS/IP; cần mở đúng Security Group |

Khuyến nghị cho đồ án: **2–3 EC2 (vd. t3.medium) chạy k3s**, tạo trước ngày quay, xoá ngay sau khi lưu bằng chứng. Kiểm tra giá và quyền lợi free tier **của chính tài khoản** trước khi tạo.

## Chart dùng lại nguyên vẹn

Không cần sửa code. Khác biệt so với local:

| Hạng mục | Local (kind) | AWS |
|---|---|---|
| Image | `kind load` | đẩy lên registry (ECR hoặc Docker Hub) rồi `--set gateway.image.repository=...,catalogue.image.repository=...` |
| Truy cập Gateway | NodePort 30080 → `localhost:8080` | NodePort + Security Group (mở 30080 chỉ cho IP của bạn) hoặc `--set gateway.service.type=LoadBalancer` (có phí ELB) |
| Storage DB | StorageClass `standard` | k3s: `local-path`; EKS: cài EBS CSI driver |
| metrics-server | cài kèm `01-cluster.ps1` (bỏ `--kubelet-insecure-tls` nếu kubelet có cert hợp lệ) | cài bằng Helm tương tự |

## Checklist chi phí (trước – trong – sau)

- [ ] Đặt AWS Budget + cảnh báo (cảnh báo **không** tự chặn chi tiêu).
- [ ] Ghi lại mọi tài nguyên đã tạo: EC2, EBS, Elastic IP, Load Balancer, NAT Gateway, ECR, CloudWatch Logs.
- [ ] Không commit access key / kubeconfig; dùng IAM user quyền tối thiểu hoặc role tạm.
- [ ] Chạy `kubectl get nodes -o wide` + chụp ảnh làm bằng chứng → lưu vào `demo-evidence/08-aws-multinode/`.
- [ ] Xoá/dừng toàn bộ tài nguyên ngay sau khi quay; kiểm tra Billing/Cost Explorer sau 24 giờ.
