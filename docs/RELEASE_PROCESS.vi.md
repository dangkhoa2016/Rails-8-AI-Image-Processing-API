# Lộ trình release

Rails 8 AI Image Processing API chưa có release được công bố. Versioning và
release evidence của project bắt đầu độc lập từ root commit đã import.

## Các mốc dự kiến

- `v0.1.0`: API xử lý ảnh xác thực, xác định, dùng trực tiếp ruby-vips và libvips.
- `v0.2.0`: xử lý ảnh xác định đã hardening và benchmark.
- `v0.3.0`: xóa nền U²-NetP CPU-only nếu ONNX Runtime qualification thành công.
- `v0.4.0`: segmentation tương tác là tùy chọn và chỉ có khi MobileSAM Ruby/ONNX feasibility gate đạt.
- `v1.0.0`: chỉ khi API ổn định, security boundary, CI, CPU/RAM qualification, deployment reproducibility và model provenance hoàn tất.

## Quy tắc release

- Không tạo tag hoặc GitHub release trước khi milestone tương ứng được triển khai và xác minh độc lập.
- Dùng semantic-version tag bất biến tại chính xác commit `main` đã được review.
- Ghi nhận bằng chứng thực tế về test, security, benchmark và deployment cùng release; không tuyên bố bằng chứng chưa thu thập.
- Giữ `CHANGELOG.md` là lịch sử release của project. Các tài liệu upstream trong `docs/history/` chỉ phục vụ attribution.
