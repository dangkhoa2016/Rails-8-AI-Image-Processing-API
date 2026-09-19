# Rails 8 AI Image Processing API

[![CI](https://github.com/dangkhoa2016/Rails-8-AI-Image-Processing-API/actions/workflows/ci.yml/badge.svg)](https://github.com/dangkhoa2016/Rails-8-AI-Image-Processing-API/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> Ngôn ngữ: [English](README.md) | **Tiếng Việt**

Rails 8 API có xác thực cho xử lý ảnh xác định và xử lý ảnh AI nhẹ, CPU-only. Các phép biến đổi xác định dùng trực tiếp `ruby-vips`/libvips. U²-NetP chạy local qua ONNX Runtime, tạo foreground mask để libvips thực hiện remove-background.

## Trạng thái project

Project được giữ ở trạng thái **pre-1.0** cho tới khi hoàn tất các gate AI và deployment.

- Baseline Devise, JWT, refresh-token rotation, PostgreSQL, Rack::Attack và security vẫn được giữ nguyên.
- `GET /images/capabilities` và authenticated multipart `POST /images/process` xử lý JPEG, PNG và WebP bằng libvips với giới hạn input/output/resource tường minh.
- Authenticated `POST /images/remove-background` là public U²-NetP background-removal contract. AI fail-closed và chỉ được bật khi đặt `IMAGE_AI_ENABLED=true`.
- Model U²-NetP ONNX không được commit vào Git. Provenance, conversion recipe, filename, tensor contract và SHA-256 authority được pin và kiểm tra trước khi load runtime.
- Python không thuộc production inference. Ruby/Vips xử lý preprocessing và composition; ONNX Runtime CPU thực hiện model inference.
- Bằng chứng chất lượng segmentation với model thật và qualification CPU/8 GiB vẫn là release gate bắt buộc. Repository đã có harness để chạy các gate này nhưng không tuyên bố PASS khi chưa có observed evidence.
- Source repository không đồng nghĩa với production deployment hoặc GHCR artifact.

Gem `image_processing` được chủ đích loại khỏi kiến trúc.

## Nguồn gốc project

Project bắt đầu từ source snapshot của:

https://github.com/dangkhoa2016/Rails-8-API-Authentication

Snapshot được import thành một root commit duy nhất. Development, versioning, release, CI và deployment authority của project này là độc lập. Tài liệu upstream lịch sử trong [`docs/history/`](docs/history/) chỉ dùng cho attribution.

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

Deterministic image processing không cần AI model. Để chạy U²-NetP local, cài model đã được checksum-qualify theo provenance workflow rồi bật AI tường minh:

```bash
IMAGE_AI_ENABLED=true bin/dev
```

Model authority mặc định được mô tả tại [`docs/U2NETP_MODEL_PROVENANCE.md`](docs/U2NETP_MODEL_PROVENANCE.md).

## Public image endpoints

```text
GET  /images/capabilities
POST /images/process
POST /images/remove-background
```

Tất cả image endpoint đều yêu cầu authenticated active user.

`POST /images/remove-background` nhận JPEG, PNG hoặc WebP và trả PNG hoặc WebP. Không truyền `background` sẽ trả ảnh trong suốt; `background=#RRGGBB` dùng libvips để composite nền màu xác định.

## Kiểm tra

```bash
bin/rails test
bin/rubocop
bin/brakeman --no-pager
```

Quality gate với model thật và CPU/8 GiB qualification có harness fail-closed riêng; việc có harness không tự động là bằng chứng PASS.

## Tài liệu

- [Mục lục tài liệu](docs/README.md)
- [Image processing contract](docs/IMAGE_PROCESSING_CONTRACT.md)
- [ONNX Runtime feasibility](docs/ONNX_RUNTIME_FEASIBILITY.md)
- [U²-NetP model provenance](docs/U2NETP_MODEL_PROVENANCE.md)
- [U²-NetP preprocessing](docs/U2NETP_PREPROCESSING.md)
- [U²-NetP CPU inference](docs/U2NETP_INFERENCE.md)
- [U²-NetP background removal](docs/U2NETP_BACKGROUND_REMOVAL.md)
- [U²-NetP CPU / 8 GiB qualification](docs/benchmarks/u2netp-cpu-8gb.md)
- [Lộ trình release](docs/RELEASE_PROCESS.vi.md)
- [Changelog project](CHANGELOG.md)

## Deployment

Source tree này chưa thiết lập production deployment, image registry artifact hoặc public endpoint. Deployment qualification chỉ bắt đầu sau khi AI quality/resource qualification local hoàn tất.

## License

Project được phát hành theo [MIT License](LICENSE).
