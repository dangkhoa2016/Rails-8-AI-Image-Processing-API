# Lộ trình release

## Vòng đời phiên bản

Project được giữ ở trạng thái **pre-1.0** cho tới khi toàn bộ public product contract được qualification. Sau khi publish, Git tag là release record bất biến; project không dùng stable-version marker có thể di chuyển.

Semantics milestone khuyến nghị:

```text
pre-1.0  deterministic Vips API + security/resource hardening
pre-1.0  ONNX Runtime + public U²-NetP background removal
pre-1.0  quality model thật + CPU/8 GiB qualification
pre-1.0  MobileSAM tùy chọn, chỉ khi Ruby/ONNX feasibility gate PASS
v1.0.0   chỉ sau khi API ổn định, security, CI, reproducible deployment,
         model provenance, CPU qualification và release docs đều PASS
```

Số phiên bản pre-1.0 cụ thể chỉ được chọn khi có release candidate thật; không tạo ngược các tag lịch sử chưa từng được publish.

## Quy tắc release

- Release từ worktree `main` sạch tại đúng commit đã review.
- Chạy full Rails tests, RuboCop, Brakeman, schema/repository policy, deterministic image qualification và Docker cold-build gate.
- Với release có AI, bắt buộc có observed evidence cho background-removal quality bằng model thật và CPU/8 GiB resource gate được xác minh độc lập.
- Kiểm tra model provenance và SHA-256 trước inference qualification.
- Chỉ tạo annotated release tag sau khi candidate PASS; không di chuyển stable tag đã publish sang commit mới hơn.
- GHCR publication và deployment là các authority riêng ở giai đoạn sau. Source release không tự động chứng minh hai authority này.
- `CHANGELOG.md` là lịch sử release của project. `docs/history/` chỉ là tài liệu attribution của source baseline đã import.

## Authority hiện tại

Repository hiện chứa implementation và fail-closed qualification tooling. Khi chưa có observed qualification evidence bắt buộc, tài liệu phải ghi gate là pending thay vì suy diễn PASS từ source code hoặc sự tồn tại của test harness.
