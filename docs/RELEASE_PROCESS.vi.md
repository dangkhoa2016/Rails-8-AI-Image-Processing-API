# Lộ trình release

## Vòng đời phiên bản

`v1.0.0` là public community source release đầu tiên của project. Annotated
release tag chỉ được tạo sau khi exact accepted `main` commit PASS toàn bộ
mandatory qualification gates. Sau khi publish, tag này là bất biến.

Semantics milestones:

```text
pre-1.0  deterministic Vips API + security/resource hardening
pre-1.0  ONNX Runtime + public background removal
pre-1.0  quality model thật + CPU/8 GiB qualification
pre-1.0  MobileSAM prompt segmentation + CPU/10 GiB endpoint qualification
v1.0.0   public community source release đầu tiên
```

Document descendant public cuối của `v1.0.0` được ghi tại
[`releases/v1.0.0-acceptance.md`](releases/v1.0.0-acceptance.md).

## Quy tắc release

- Release từ worktree `main` sạch tại đúng commit đã review.
- Chạy full Rails tests, RuboCop, Brakeman, schema/repository policy, deterministic image qualification và Docker cold-build gate.
- Với release có AI, bắt buộc có observed real-model correctness/quality evidence cho mọi AI operation mới được public và resource qualification độc lập cho workload của release.
- Kiểm tra model provenance và SHA-256 trước inference qualification.
- Chỉ tạo annotated `v1.0.0` tag sau khi exact release candidate PASS toàn bộ mandatory gates; sau khi publish, không di chuyển tag.
- GHCR publication và deployment là các authority riêng ở giai đoạn sau. Source release không tự động chứng minh hai authority này.
- `CHANGELOG.md` là lịch sử release của project. `docs/history/` chỉ là tài liệu attribution của source baseline đã import.

## Authority hiện tại

`v1.0.0` là public community source release đầu tiên của project và chứa scope
cuối đã accept cho BiRefNet và MobileSAM. Corrective này vẫn giữ version
`v1.0.0`; GHCR và production deployment vẫn là authority riêng.
