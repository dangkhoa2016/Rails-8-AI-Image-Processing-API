# Phát hành Docker image

Container package chính thức của Rails 8 AI Image Processing API là:

`ghcr.io/dangkhoa2016/rails-8-ai-image-processing-api`

Release publisher build chính xác annotated release tag thành Linux
multi-platform OCI image cho:

- `linux/amd64`
- `linux/arm64`

## Canonical release aliases

Với `v1.0.0`, publisher duy trì các alias sau cùng trỏ tới canonical
multi-platform OCI index:

```text
ghcr.io/dangkhoa2016/rails-8-ai-image-processing-api:v1.0.0
ghcr.io/dangkhoa2016/rails-8-ai-image-processing-api:1.0.0
ghcr.io/dangkhoa2016/rails-8-ai-image-processing-api:latest
ghcr.io/dangkhoa2016/rails-8-ai-image-processing-api:sha-<short-source-sha>
```

Người dùng thông thường nên ưu tiên `v1.0.0` hoặc một immutable release tag
khác. Docker sẽ tự động chọn đúng platform child manifest khi pull một
multi-platform alias.

## Explicit platform aliases

GitHub Container Registry liệt kê các child manifest của multi-platform image
thành các package version riêng. Để các version này dễ hiểu trên giao diện
GitHub Packages, publisher còn tạo hai one-platform OCI alias:

```text
ghcr.io/dangkhoa2016/rails-8-ai-image-processing-api:v1.0.0-amd64
ghcr.io/dangkhoa2016/rails-8-ai-image-processing-api:v1.0.0-arm64
```

Các alias này không build lại ứng dụng. Chúng wrap đúng runnable child manifest
đã có trong canonical release index và mang OCI annotation rõ ràng cho title,
description, source, license, version và revision.

Canonical build cũng gắn annotation trực tiếp cho các runnable child manifest
`linux/amd64` và `linux/arm64`. Vì vậy khi mở trực tiếp trang digest trong
GitHub Packages, người review có thể nhận biết architecture dễ dàng hơn.

## Provenance và SBOM entries

Publisher giữ BuildKit provenance và SBOM ở trạng thái bật. Vì vậy GitHub
Packages có thể hiển thị thêm các version `sha256:...` không có tag với platform
`unknown/unknown`. Đây là supply-chain attestation, không phải runnable
application image.

Release verifier phân biệt runnable AMD64/ARM64 manifest với attestation manifest
và yêu cầu chính xác một runnable child cho mỗi architecture được hỗ trợ.

## AI model weights là runtime authority bên ngoài image

Docker image **không** nhúng các model weight BiRefNet hoặc MobileSAM đã
qualification. AI endpoint tiếp tục fail-closed trừ khi:

1. các model file đã qualification được mount đúng vào các path mong đợi dưới
   `/models`; và
2. cấu hình `IMAGE_AI_ENABLED=true`.

Thiết kế này giữ application image reproducible, đồng thời tách biệt authority
về filename, byte-size và SHA-256 của model khỏi container image.

## Package visibility

GHCR package mới mặc định là private dù source repository là public. Trước khi
công bố anonymous community pull, cần đổi visibility của container package sang
**Public** trong GitHub Package settings và xác minh pull không đăng nhập.

Repository visibility và package visibility là hai thiết lập độc lập.

## Verification

Publication workflow kiểm tra immutable Buildx output trước khi tuyên bố thành
công. Workflow xác minh:

- annotated release tag resolve đúng checked-out source commit;
- tất cả canonical alias resolve đúng release revision;
- canonical index chứa đúng child digest cho `linux/amd64` và
  `linux/arm64`;
- `v1.0.0-amd64` chỉ chứa một runnable AMD64 child;
- `v1.0.0-arm64` chỉ chứa một runnable ARM64 child;
- OCI annotation version/revision/title/description đều tồn tại.

Có thể kiểm tra thủ công bằng:

```bash
docker buildx imagetools inspect \
  ghcr.io/dangkhoa2016/rails-8-ai-image-processing-api:v1.0.0

docker buildx imagetools inspect \
  ghcr.io/dangkhoa2016/rails-8-ai-image-processing-api:v1.0.0-amd64

docker buildx imagetools inspect \
  ghcr.io/dangkhoa2016/rails-8-ai-image-processing-api:v1.0.0-arm64
```

Sau khi package visibility là Public, có thể xác minh anonymous pull:

```bash
docker logout ghcr.io 2>/dev/null || true
docker pull ghcr.io/dangkhoa2016/rails-8-ai-image-processing-api:v1.0.0
```
