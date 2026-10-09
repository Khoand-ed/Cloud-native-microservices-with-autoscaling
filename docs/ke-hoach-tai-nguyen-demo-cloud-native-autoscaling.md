# Kế hoạch chuẩn bị tài nguyên trước khi quay demo
## Đồ án: Cloud-native Microservices with Autoscaling

> **Phương án:** phát triển và kiểm thử cục bộ trước, sau đó triển khai AWS khi cần xác minh yêu cầu multi-node.  
> **Ngân sách:** ưu tiên miễn phí; không duy trì tài nguyên AWS chạy nền.  
> **Mục tiêu:** chỉ bắt đầu quay khi ứng dụng, Kubernetes, monitoring, autoscaling và load testing đã được kiểm chứng.

---

## 1. Phạm vi demo và tiêu chí hoàn thành

Theo mô tả đồ án, hệ thống cần có:

- 3 thành phần: **API Gateway/API**, **Catalogue Service** và **Database**.
- Đóng gói dịch vụ bằng Docker; cung cấp Helm chart hoặc Kubernetes manifests.
- Triển khai lên Kubernetes; cấu hình `resources.requests` và `resources.limits`.
- Cấu hình **HPA (Horizontal Pod Autoscaler)** dựa trên CPU.
- Thu thập metrics và trình bày trên **Prometheus + Grafana**.
- Dùng **k6** tạo tải, ghi nhận số Pod thay đổi và phân tích CPU, request rate, hành vi autoscaling.
- Báo cáo số liệu, ảnh chụp và bài học rút ra.

### Tiêu chí “sẵn sàng quay”

| Hạng mục | Điều kiện cần đạt | Bằng chứng cần lưu |
|---|---|---|
| Ứng dụng | API hoạt động; API Gateway/API gọi được Catalogue; Catalogue đọc/ghi được dữ liệu mẫu trong DB | Lệnh gọi API thành công, dữ liệu trả về |
| Container | Các image build được và container khởi động ổn định | Lệnh build/run, trạng thái container |
| Kubernetes | Workload ở trạng thái `Running`/`Ready`; Service truy cập được | `kubectl get pods,svc,deploy` |
| Tài nguyên | Deployment có CPU/memory requests và limits phù hợp | YAML đã áp dụng |
| HPA | HPA đọc được metrics và có thể tăng/giảm replica khi đủ điều kiện | `kubectl get hpa -w`, số replica trước/sau |
| Monitoring | Prometheus thu thập metrics; Grafana có dashboard dùng được | Dashboard và truy vấn/biểu đồ |
| Load test | Kịch bản k6 chạy ổn định, tải đủ để kích hoạt HPA trong môi trường thử nghiệm | Script, thời gian chạy, kết quả k6 |
| AWS (nếu quay) | Cluster multi-node sẵn sàng; truy cập và đường triển khai đã được thử trước | `kubectl get nodes`, trạng thái workload |
| Báo cáo | Có số liệu, ảnh, sơ đồ kiến trúc và nhận xét | Thư mục bằng chứng đã sắp xếp |

---

## 2. Bảng kế hoạch chuẩn bị theo giai đoạn

> Có thể phân công một người phụ trách chính cho mỗi hàng; cả nhóm cùng xác nhận cột “Điều kiện hoàn thành”.

| Giai đoạn | Công việc | Tài nguyên/công cụ cần có | Người phụ trách gợi ý | Điều kiện hoàn thành |
|---|---|---|---|---|
| 0. Chốt phạm vi | Chốt luồng request, endpoint demo, dữ liệu mẫu, tiêu chí autoscaling và phần nào sẽ quay trên AWS | Sơ đồ kiến trúc, danh sách endpoint, tiêu chí demo | Cả nhóm | Không còn mơ hồ về luồng demo và bằng chứng cần thu |
| 1. Máy phát triển | Kiểm tra dung lượng ổ đĩa, RAM, CPU, quyền cài đặt và kết nối mạng | Máy Windows/Linux, Git, terminal, trình soạn thảo | Thành viên phụ trách môi trường | Chạy được lệnh kiểm tra và clone repository |
| 2. Ứng dụng | Hoàn thiện API, Catalogue Service, DB và dữ liệu seed | Ngôn ngữ/framework đã chọn, DB, file cấu hình môi trường | Phụ trách backend | Các endpoint chính chạy được và có dữ liệu mẫu |
| 3. Docker | Viết Dockerfile, cấu hình mạng nội bộ, biến môi trường và health check nếu phù hợp | Docker Engine/Desktop hoặc runtime tương thích | Phụ trách container | Build thành công; các container giao tiếp được |
| 4. Kubernetes cục bộ | Tạo cluster local; triển khai manifests/Helm; cấu hình Service, ConfigMap/Secret và storage nếu DB cần dữ liệu bền vững | Minikube, kind hoặc k3s; `kubectl`; Helm nếu dùng | Phụ trách Kubernetes | Pod Ready, API truy cập được qua đường dẫn đã chọn |
| 5. Requests/limits | Đặt CPU/memory requests và limits cho workload cần thiết; kiểm tra DB có yêu cầu lưu trữ bền vững không | YAML/Helm values | Phụ trách Kubernetes + backend | Cấu hình được áp dụng và workload vẫn hoạt động |
| 6. Metrics và HPA | Cài/kiểm tra metrics-server; khai báo HPA dựa trên CPU; kiểm tra `kubectl top` | metrics-server, HPA manifest | Phụ trách autoscaling | Metrics có dữ liệu, HPA không ở trạng thái thiếu metrics |
| 7. Monitoring | Triển khai Prometheus + Grafana; tạo hoặc chỉnh dashboard thể hiện CPU, request rate và số replica | kube-prometheus-stack hoặc cài đặt tương đương | Phụ trách monitoring | Dashboard có dữ liệu đúng trong lúc thử tải |
| 8. Load test | Viết kịch bản k6, xác định mức tải tăng dần, thời gian giữ tải và thời gian nghỉ | k6, endpoint thử nghiệm, script được lưu trong repo | Phụ trách kiểm thử | Có thể lặp lại bài test và lưu được kết quả |
| 9. Diễn tập local | Chạy trọn luồng từ trạng thái bình thường → tăng tải → HPA scale → giảm tải; kiểm tra lỗi thường gặp | Tất cả thành phần trên | Cả nhóm | Demo lặp lại được; biết rõ cửa sổ terminal/dashboard cần mở |
| 10. AWS (chỉ khi cần) | Chọn cách dựng multi-node phù hợp yêu cầu môn học; chuẩn bị quyền truy cập, mạng, image registry và cấu hình triển khai | Tài khoản AWS, IAM tối thiểu cần thiết, cluster/EC2, registry nếu dùng | Phụ trách cloud | `kubectl get nodes` cho thấy các node dự kiến; workload triển khai được |
| 11. Chốt kịch bản quay | Chốt thứ tự thao tác, câu dẫn, thời lượng, góc quay và phương án dự phòng | Kịch bản, công cụ quay màn hình, thư mục lưu bằng chứng | Cả nhóm | Có ít nhất một buổi tổng duyệt hoàn chỉnh |
| 12. Quay chính thức | Làm sạch terminal, ẩn thông tin nhạy cảm, kiểm tra dashboard, chạy bài test và ghi hình | Máy quay màn hình, kịch bản, log và kết quả test | Người dẫn demo + người điều khiển | Video rõ ràng, có đủ bằng chứng kỹ thuật và không lộ credentials |

---

## 3. Danh sách tài nguyên cần chuẩn bị

### 3.1. Phần mềm trên máy phát triển

| Tài nguyên | Mức độ | Mục đích | Ghi chú |
|---|---|---|---|
| Git | Bắt buộc | Quản lý mã nguồn và lịch sử thay đổi | Dùng chung repository |
| Docker Engine hoặc Docker Desktop | Bắt buộc cho quy trình Docker | Build và chạy container | Kiểm tra yêu cầu hệ điều hành/giấy phép của phiên bản đang dùng |
| `kubectl` | Bắt buộc | Quản lý cluster Kubernetes | Phiên bản tương thích với cluster |
| Một công cụ Kubernetes local: Minikube **hoặc** kind **hoặc** k3s | Bắt buộc cho giai đoạn local | Phát triển và diễn tập không cần AWS | Không cần cài cả ba; chọn một |
| Helm | Có điều kiện | Triển khai bằng chart nếu nhóm chọn Helm | Nếu dùng manifests thuần thì không bắt buộc |
| k6 | Bắt buộc cho load test | Sinh tải và lưu kết quả kiểm thử | Lưu script trong repository |
| Trình duyệt | Bắt buộc | Kiểm tra API/Grafana và quay màn hình | Chuẩn bị bookmark URL local |
| Trình soạn thảo | Khuyến nghị | Chỉnh code/YAML và xem log | VS Code hoặc công cụ tương đương |
| Công cụ quay màn hình | Bắt buộc khi quay | Ghi lại demo | Thử âm thanh, độ phân giải và dung lượng trước |

### 3.2. Thành phần hệ thống

| Thành phần | Cần chuẩn bị | Cần kiểm tra trước khi quay |
|---|---|---|
| API Gateway/API | Endpoint, route, xử lý lỗi và cấu hình môi trường | Request mẫu trả đúng status/body |
| Catalogue Service | Dữ liệu sản phẩm/catalogue mẫu và endpoint cần demo | API truy cập được qua Service phù hợp |
| Database | Schema, dữ liệu seed, thông tin kết nối | Service kết nối DB ổn định; xác định rõ cách lưu dữ liệu |
| Container images | Dockerfile và tag có thể nhận biết | Image build được; image pull được trong môi trường chạy |
| Kubernetes manifests/Helm chart | Deployment, Service, cấu hình, requests/limits, HPA | Không còn cấu hình phụ thuộc đường dẫn hoặc biến môi trường riêng của máy |
| metrics-server | Nguồn metrics tài nguyên cho HPA | `kubectl top pods`/`kubectl top nodes` có dữ liệu khi môi trường hỗ trợ |
| Prometheus | Scrape cấu hình và metrics cần quan sát | Metrics cập nhật trong lúc chạy thử |
| Grafana | Dashboard, truy vấn và khoảng thời gian hiển thị phù hợp | Biểu đồ không trống và đơn vị/nhãn dễ giải thích |
| k6 | Script, URL đích, mức tải và thời lượng | Chạy được nhiều lần, không vô tình gửi tải vào endpoint sản xuất |
| AWS (nếu dùng) | Cluster multi-node, quyền IAM, network, image registry và kubeconfig | Xác nhận truy cập, trạng thái node và workload trước giờ quay |

### 3.3. Tài liệu và bằng chứng

- [ ] Sơ đồ kiến trúc và luồng request giữa API, Catalogue Service và DB.
- [ ] File Dockerfile và manifests/Helm chart.
- [ ] Cấu hình requests/limits và HPA.
- [ ] Lệnh/trạng thái Pod, Service, node và HPA.
- [ ] Dashboard Prometheus/Grafana với metrics cần thiết.
- [ ] Script k6 và kết quả các lần chạy.
- [ ] Bảng ghi thời điểm, mức tải, replica trước/sau, CPU và kết quả request.
- [ ] Ảnh chụp màn hình phục vụ báo cáo.
- [ ] Kịch bản demo và phương án dự phòng.
- [ ] README hướng dẫn tái tạo môi trường.

---

## 4. Thứ tự chuẩn bị khuyến nghị

Thực hiện theo thứ tự dưới đây để phát hiện lỗi sớm, trước khi tiêu tốn thời gian hoặc tiền cho AWS.

1. **Chốt kiến trúc và luồng demo.** Xác định endpoint nào sẽ được gọi và metrics nào chứng minh autoscaling.
2. **Hoàn thiện ứng dụng và DB ở chế độ chạy đơn giản.** Kiểm tra luồng dữ liệu trước khi thêm Kubernetes.
3. **Containerise.** Build và kiểm thử từng image; xác minh kết nối giữa các container.
4. **Triển khai Kubernetes local.** Dùng một công cụ local; áp dụng manifests/Helm và xác minh Service.
5. **Thiết lập requests/limits và metrics-server.** Kiểm tra metrics trước khi cấu hình HPA.
6. **Cấu hình HPA.** Xác minh target CPU, số replica tối thiểu/tối đa và hành vi scale.
7. **Thêm Prometheus/Grafana.** Chuẩn bị dashboard trước buổi diễn tập để không phải chỉnh trong lúc quay.
8. **Viết và hiệu chỉnh k6.** Tăng tải từ từ; tránh giả định rằng mọi mức tải đều chắc chắn kích hoạt scale.
9. **Diễn tập trọn luồng local.** Lưu log và số liệu; ghi lại thời gian phản ứng và thời gian scale down.
10. **Đánh giá yêu cầu multi-node.** Nếu giảng viên yêu cầu bằng chứng cluster AWS multi-node, triển khai và kiểm thử AWS riêng trước ngày quay. Nếu local đủ cho phần lớn demo, chỉ dùng AWS cho phần cần chứng minh trên cloud.
11. **Tổng duyệt và quay.** Chuẩn bị các cửa sổ terminal, dashboard và kịch bản; quay thử một đoạn để kiểm tra chất lượng.
12. **Thu dọn tài nguyên cloud.** Sau khi đã lưu log, ảnh và số liệu, dừng/xóa tài nguyên tính phí theo đúng cách của dịch vụ.

---

## 5. Kịch bản kiểm tra kỹ thuật trước khi quay

Thứ tự thao tác mẫu:

1. Hiển thị các node và trạng thái workload:
   ```bash
   kubectl get nodes -o wide
   kubectl get deployments,services,pods
   ```
2. Hiển thị trạng thái autoscaler:
   ```bash
   kubectl get hpa
   kubectl describe hpa <ten-hpa>
   ```
3. Theo dõi HPA trong một terminal:
   ```bash
   kubectl get hpa -w
   ```
4. Theo dõi số Pod ở terminal khác:
   ```bash
   kubectl get pods -w
   ```
5. Mở dashboard Grafana đã chuẩn bị; xác nhận khoảng thời gian đang hiển thị bao trùm bài thử.
6. Chạy k6 từ máy có thể truy cập endpoint thử nghiệm:
   ```bash
   k6 run <ten-script>.js
   ```
7. Quan sát request rate, CPU và replica trong suốt bài thử.
8. Chờ hệ thống ổn định sau tải; ghi lại số replica và metrics sau khi giảm tải.
9. Lưu output k6, ảnh dashboard và các trạng thái `kubectl` vào thư mục bằng chứng.

**Lưu ý:** tên HPA, tên script và endpoint ở trên là chỗ cần thay bằng giá trị thực của nhóm. Không nên quay bằng lệnh chưa được thử trước. HPA cần thời gian để thu thập metrics và phản ứng; scale không nhất thiết xảy ra ngay khi bắt đầu tải. Việc scale down cũng có thể chậm hơn scale up.

---

## 6. Checklist xác nhận sẵn sàng quay

### Ứng dụng và container
- [ ] API, Catalogue Service và DB đều hoạt động.
- [ ] Endpoint demo và dữ liệu mẫu đã được xác minh.
- [ ] Image có tag rõ ràng; không phụ thuộc image chỉ tồn tại trên máy khác.
- [ ] Cấu hình môi trường không chứa mật khẩu hoặc token hard-code.

### Kubernetes và autoscaling
- [ ] Cluster đúng môi trường đã chọn; node ở trạng thái sẵn sàng.
- [ ] Pod Ready và Service truy cập được.
- [ ] `resources.requests` và `resources.limits` đã được cấu hình.
- [ ] metrics-server hoạt động và metrics có dữ liệu.
- [ ] HPA hiển thị target/current metrics hợp lệ, không bị thiếu metrics.
- [ ] Đã thử tăng tải và quan sát được thay đổi replica trong môi trường kiểm thử.

### Monitoring và load testing
- [ ] Prometheus nhận được metrics cần thiết.
- [ ] Grafana dashboard hiển thị đúng CPU, request rate và replica hoặc chỉ số tương đương đã chọn.
- [ ] Script k6 đã được thử và thời lượng đủ để quan sát quá trình scale.
- [ ] Có kết quả test, log và ảnh chụp; biết cách giải thích số liệu.
- [ ] Đã ghi nhận cả điểm giới hạn: độ trễ, lỗi request, ngưỡng HPA và thời gian scale.

### AWS và quay màn hình
- [ ] Nếu cần AWS: xác nhận node/cluster, quyền truy cập và workload trước giờ quay.
- [ ] Không để lộ access key, secret, kubeconfig nhạy cảm, email riêng hoặc thông tin thanh toán.
- [ ] Dashboard, terminal và cửa sổ trình duyệt đã được sắp xếp.
- [ ] Thông báo, tab và dữ liệu cá nhân không liên quan đã được đóng/ẩn.
- [ ] Có bản ghi thử và đủ dung lượng ổ đĩa.
- [ ] Có phương án dự phòng: log/ảnh đã lưu và kịch bản diễn giải nếu mạng hoặc AWS gặp sự cố.

---

## 7. Kiểm soát chi phí AWS

**Nguyên tắc:** local-first; AWS chỉ được bật trong khoảng thời gian cần kiểm chứng hoặc quay phần bắt buộc.

- Không mặc định rằng tài khoản mới luôn có free tier đủ cho toàn bộ đồ án. Điều kiện miễn phí thay đổi theo tài khoản, khu vực, loại tài nguyên và thời điểm.
- Trước khi tạo tài nguyên, kiểm tra giá hiện hành và quyền lợi miễn phí của chính tài khoản AWS.
- Tránh tạo EKS chỉ vì muốn có Kubernetes: control plane, worker nodes, ổ đĩa, địa chỉ IP, load balancer, NAT Gateway, lưu trữ image/log và truyền dữ liệu có thể phát sinh chi phí riêng.
- Nếu tự dựng cluster trên EC2, máy ảo, ổ đĩa và các thành phần mạng vẫn có thể tính phí; tự quản lý Kubernetes không đồng nghĩa với miễn phí.
- Chỉ tạo số node tối thiểu đáp ứng yêu cầu của bài demo; không để instance hoặc cluster chạy qua đêm nếu không cần.
- Đặt AWS Budget và cảnh báo chi phí trước khi bắt đầu. **Budget/cảnh báo không phải là công tắc tự động chặn chi tiêu.**
- Ghi lại tài nguyên đã tạo để tránh bỏ sót: EC2, EBS, Elastic IP, Load Balancer, NAT Gateway, cluster, registry và log.
- Sau demo, lưu kết quả rồi xóa/dừng tài nguyên không còn cần; kiểm tra lại trang Billing/Cost Explorer. Một số dịch vụ vẫn có thể tính phí sau khi workload dừng nếu tài nguyên tính phí còn tồn tại.
- Không commit credentials vào Git, không đưa secret vào video và thu hồi thông tin xác thực nếu lỡ bị lộ.

### Phương án chi phí thấp đề xuất

| Giai đoạn | Môi trường | Mục tiêu |
|---|---|---|
| Phát triển | Máy cá nhân | Hoàn thiện code, Dockerfile, manifests và dữ liệu mẫu |
| Diễn tập chính | Kubernetes local | Kiểm thử HPA, Prometheus/Grafana và k6; thu thập bằng chứng |
| Xác minh cloud | AWS trong thời gian ngắn, khi cần | Chứng minh triển khai cloud/multi-node theo yêu cầu môn học |
| Quay và hậu kiểm | Local hoặc AWS đã tổng duyệt | Quay phần phù hợp; lưu log/ảnh/số liệu |
| Sau demo | Thu dọn AWS | Xóa/dừng tài nguyên không cần và kiểm tra chi phí |

---

## 8. Cấu trúc thư mục đề xuất để lưu bằng chứng

```text
demo-evidence/
├── 01-architecture/
├── 02-application-api/
├── 03-docker/
├── 04-kubernetes/
├── 05-hpa/
├── 06-prometheus-grafana/
├── 07-k6-results/
├── 08-aws-multinode/
├── 09-recordings/
└── README.md
```

Chỉ tạo thư mục `08-aws-multinode/` nếu nhóm thực sự triển khai AWS. Không đưa secret, access key, kubeconfig hoặc dữ liệu nhạy cảm vào thư mục bằng chứng.

---

## 9. Quyết định cần chốt trong nhóm

- [ ] Chọn một công cụ Kubernetes local: Minikube, kind hoặc k3s.
- [ ] Chốt dùng Helm chart hay Kubernetes manifests thuần.
- [ ] Chốt DB và cách lưu dữ liệu.
- [ ] Chốt endpoint, mức tải k6 và metrics cần thể hiện.
- [ ] Xác nhận giảng viên có bắt buộc demo trên AWS multi-node trực tiếp hay chỉ cần tài liệu/bằng chứng triển khai.
- [ ] Chọn người phụ trách từng giai đoạn và người dẫn demo.
- [ ] Chốt thời lượng quay và nơi lưu video/bằng chứng.

**Điểm cần xác minh sớm nhất:** yêu cầu “Kubernetes multi-node (AWS)” trong mô tả đồ án. Hãy hỏi giảng viên xem bắt buộc phải quay trực tiếp trên AWS hay có thể dùng local cho phần autoscaling và chỉ triển khai AWS để chứng minh multi-node. Điều này quyết định phần lớn công sức chuẩn bị và rủi ro chi phí.

---

*Tài liệu này là kế hoạch chuẩn bị; các công cụ, cấu hình, ngưỡng HPA, dung lượng máy và chi phí thực tế cần được xác minh theo ứng dụng, môi trường và tài khoản AWS của nhóm.*
