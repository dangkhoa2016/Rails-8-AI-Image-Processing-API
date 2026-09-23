# Lộ trình release

## Vòng đời phiên bản

`v1.0.0` là public community source release đầu tiên đã finalize của project.
Git tag là release record bất biến sau khi publish; project không di chuyển
stable-version tag đã publish sang commit khác chỉ vì cleanup.

Semantics milestones:

```text
pre-1.0  deterministic Vips API + security/resource hardening
pre-1.0  ONNX Runtime + public background removal
pre-1.0  quality model thật + CPU/8 GiB qualification
v1.0.0   public community source release đầu tiên (finalize 2026-09-22)
v1.1.0   MobileSAM prompt segmentation source release (2026-09-23)
```

Document descendant public cuối của `v1.0.0` được ghi tại
[`releases/v1.0.0-acceptance.md`](releases/v1.0.0-acceptance.md).

## Quy tắc release

- Release từ worktree `main` sạch tại đúng commit đã review.
- Chạy full Rails tests, RuboCop, Brakeman, schema/repository policy, deterministic image qualification và Docker cold-build gate.
- Với release có AI, bắt buộc có observed real-model correctness/quality evidence cho mọi AI operation mới được public và resource qualification độc lập cho workload của release.
- Kiểm tra model provenance và SHA-256 trước inference qualification.
- Chỉ tạo annotated release tag sau khi candidate PASS; khi đã publish, không di chuyển tag.
- GHCR publication và deployment là các authority riêng ở giai đoạn sau. Source release không tự động chứng minh hai authority này.
- `CHANGELOG.md` là lịch sử release của project. `docs/history/` chỉ là tài liệu attribution của source baseline đã import.

## Authority hiện tại

`v1.0.0` vẫn là public community source release đầu tiên và bất biến.
`v1.1.0` là forward source release cho MobileSAM segmentation. Không
force-rewrite `main` hoặc di chuyển `v1.0.0`; GHCR và production deployment
vẫn là authority riêng.
