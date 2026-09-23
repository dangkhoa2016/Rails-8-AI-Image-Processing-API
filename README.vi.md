# Rails 8 AI Image Processing API

[![CI](https://github.com/dangkhoa2016/Rails-8-AI-Image-Processing-API/actions/workflows/ci.yml/badge.svg)](https://github.com/dangkhoa2016/Rails-8-AI-Image-Processing-API/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> Ngôn ngữ: [English](README.md) | **Tiếng Việt**

Rails 8 API có xác thực cho xử lý ảnh xác định và xử lý ảnh AI nhẹ, CPU-only.

- Các phép biến đổi xác định dùng trực tiếp `ruby-vips`/libvips.
- AI remove-background chạy BiRefNet local qua ONNX Runtime CPU backend bên
  trong Ruby, tạo foreground mask để libvips thực hiện composition.

`v1.0.0` là public source release đầu tiên của project. `v1.1.0` bổ sung API
segment bằng MobileSAM. Xem
[`docs/releases/v1.1.0-acceptance.md`](docs/releases/v1.1.0-acceptance.md) cho
scope release mới; record bất biến của `v1.0.0` vẫn ở
[`docs/releases/v1.0.0-acceptance.md`](docs/releases/v1.0.0-acceptance.md).

## Trạng thái project

`v1.1.0` là source-release candidate hiện tại; `v1.0.0` vẫn là public community source release đầu tiên và bất biến.

- Baseline Devise, JWT, refresh-token rotation, PostgreSQL, Rack::Attack và
  security hiện có là nền tảng xác thực.
- `GET /images/capabilities` và authenticated multipart `POST /images/process`
  xử lý JPEG, PNG và WebP bằng libvips với giới hạn input/output/resource
  tường minh.
- Authenticated `POST /images/remove-background` là AI background-removal
  contract.
- Authenticated `POST /images/segment` là MobileSAM prompt-segmentation
  contract. Endpoint nhận đúng một point hoặc box prompt và trả binary PNG mask
  theo kích thước ảnh nguồn.
- AI fail-closed và chỉ được bật khi đặt `IMAGE_AI_ENABLED=true`.
- Artifact ONNX của BiRefNet và MobileSAM không được commit vào Git.
  Provenance, filename, tensor contract, dung lượng và SHA-256 authority được
  pin trong `config/models/` và kiểm tra trước khi load runtime.
- Python không thuộc production inference. Ruby/Vips xử lý preprocessing và
  composition; ONNX Runtime CPU backend thực hiện model inference.
- Một CPU runtime qualification chính thức đã PASS trong provider-managed
  Modal Function container với memory request 8192 MiB và hard limit
  8192 MiB. Đây là capacity qualification, không phải production-traffic hay
  SLA claim. Xem [`docs/BIREFNET_CPU_QUALIFICATION.vi.md`](docs/BIREFNET_CPU_QUALIFICATION.vi.md).
- Source repository này không ngụ ý production deployment, hosted public
  endpoint hoặc GHCR artifact.

Gem `image_processing` được chủ đích loại khỏi kiến trúc.

## Nguồn gốc project

Project bắt đầu từ source snapshot của:

https://github.com/dangkhoa2016/Rails-8-API-Authentication

Snapshot được import thành một root commit duy nhất. Development, versioning,
release, CI và deployment authority của project này là độc lập. Tài liệu
upstream lịch sử trong [`docs/history/`](docs/history/) chỉ dùng cho attribution.

## Phát triển local

### Điều kiện cần

- Ruby 3.3
- Bundler
- PostgreSQL
- libvips

Chuẩn bị ứng dụng:

```bash
cp .env.sample .env
bundle install
bin/rails db:prepare
```

Deterministic image processing không cần AI model. Để chạy BiRefNet local,
cài model đã được checksum-qualify theo provenance workflow rồi bật AI tường
minh:

```bash
script/models/fetch_birefnet
IMAGE_AI_ENABLED=true bin/dev
```

Artifact authority mặc định của BiRefNet được mô tả tại
[`docs/BIREFNET_CPU_QUALIFICATION.vi.md`](docs/BIREFNET_CPU_QUALIFICATION.vi.md).

## Public image endpoints

```text
GET  /images/capabilities
POST /images/process
POST /images/remove-background
POST /images/segment
```

Tất cả image endpoint đều yêu cầu authenticated active user.

`POST /images/process` là deterministic Vips pipeline. Endpoint này yêu cầu
tham số `operations` và nhận input JPEG, PNG hoặc WebP.

`POST /images/remove-background` nhận JPEG, PNG hoặc WebP và trả PNG hoặc
WebP. Không truyền `background` sẽ trả ảnh trong suốt; `background=#RRGGBB`
dùng libvips để composite nền màu xác định. Tham số tùy chọn: `feather`
(0–20), `format` (`png`/`webp`) và `quality` (1–100). Mask provider mặc định
của endpoint này là BiRefNet.

`POST /images/segment` nhận JPEG, PNG hoặc WebP cùng đúng một JSON prompt.
Point prompt dùng `{"type":"point","x":...,"y":...,"label":0|1}`; box prompt
dùng `{"type":"box","x0":...,"y0":...,"x1":...,"y1":...}`. Response là
single-band binary PNG mask theo geometry của ảnh nguồn sau autorotate.
MobileSAM encoder và prompt-mask decoder ONNX session được cache một lần mỗi
process; mỗi request chạy một encoder inference và một decoder inference.

AI fail-closed: khi `IMAGE_AI_ENABLED` không phải `true`, endpoint trả về
`503 AI model is unavailable`.

## Kiểm tra

```bash
bin/rails test
bin/rubocop
bin/brakeman --no-pager
```

BiRefNet quality validation và CPU runtime qualification 8-GiB được mô tả trong
[`docs/BIREFNET_CPU_QUALIFICATION.vi.md`](docs/BIREFNET_CPU_QUALIFICATION.vi.md).

## Tài liệu

- [Mục lục tài liệu](docs/README.md)
- [Image processing contract](docs/IMAGE_PROCESSING_CONTRACT.md)
- [ONNX Runtime feasibility](docs/ONNX_RUNTIME_FEASIBILITY.md)
- [BiRefNet CPU qualification](docs/BIREFNET_CPU_QUALIFICATION.vi.md)
- [v1.1.0 acceptance record](docs/releases/v1.1.0-acceptance.md)
- [v1.0.0 acceptance record](docs/releases/v1.0.0-acceptance.md)
- [Lộ trình release](docs/RELEASE_PROCESS.vi.md)
- [Changelog project](CHANGELOG.md)

## Deployment

Repository này không thiết lập hosted production deployment, live public
endpoint hoặc image registry artifact. Deployment là hoạt động riêng sau này,
ngoài scope của source release.

## License

Project được phát hành theo [MIT License](LICENSE).
