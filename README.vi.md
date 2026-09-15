# Rails 8 AI Image Processing API

[![CI](https://github.com/dangkhoa2016/Rails-8-AI-Image-Processing-API/actions/workflows/ci.yml/badge.svg)](https://github.com/dangkhoa2016/Rails-8-AI-Image-Processing-API/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> Ngôn ngữ: [English](README.md) | **Tiếng Việt**

Một Rails 8 API có xác thực cho xử lý ảnh xác định. Project cung cấp xử lý trực
tiếp bằng `ruby-vips`/libvips và có feasibility spike ONNX Runtime CPU chỉ cho
test; application API không cung cấp xử lý AI.

## Trạng thái project

Repository có deterministic image-processing API có xác thực và một local
release marker.

- Baseline Devise, JWT, refresh token, PostgreSQL, Rack::Attack và security test vẫn được giữ nguyên.
- `GET /images/capabilities` và authenticated multipart `POST /images/process` cung cấp xử lý Vips xác định cho JPEG, PNG và WebP. Gem `image_processing` không thuộc kiến trúc này.
- Feasibility spike ONNX Runtime CPU chỉ cho test kiểm tra sigmoid fixture 105 byte có checksum cố định. Nó không thêm U²-NetP hay model thật khác, API endpoint, job, GPU dependency hoặc Python inference service; xem [ONNX Runtime feasibility](docs/ONNX_RUNTIME_FEASIBILITY.md).
- `v1.0.0` là mutable local release marker duy nhất; nó không đại diện remote release hoặc production deployment.

## Nguồn gốc project

Project khởi đầu từ source snapshot của:

https://github.com/dangkhoa2016/Rails-8-API-Authentication

Source snapshot được import thành một root commit duy nhất. Lịch sử phát triển, phiên bản, release, CI provenance và deployment của project này hoàn toàn độc lập từ thời điểm đó.

Các tài liệu upstream lịch sử chỉ được giữ lại để attribution trong [`docs/history/`](docs/history/); chúng không phải release hoặc deployment authority của project này.

## Phát triển local

### Điều kiện cần

- Ruby 3.3
- Bundler
- PostgreSQL local
- libvips local (bắt buộc trước giai đoạn triển khai Vips trực tiếp)

Sao chép file môi trường local và chuẩn bị database:

```bash
cp .env.sample .env
bundle install
bin/rails db:prepare
```

Tên database development/test mặc định:

```text
rails_8_ai_image_processing_api_development
rails_8_ai_image_processing_api_test
```

Chạy ứng dụng bằng `bin/dev`. Xem các image route có xác thực và authentication
route trong `config/routes.rb` để biết contract chính xác.

## Kiểm tra

```bash
bin/rails test
bin/rubocop
bin/brakeman --no-pager
```

## Tài liệu

- [Mục lục tài liệu](docs/README.md)
- [Phân quyền](docs/ACCESS_CONTROL.md)
- [Vòng đời JWT](docs/JWT_LIFECYCLE.md)
- [Rate limiting](docs/RATE_LIMITING.md)
- [Kế hoạch deployment](docs/DEPLOYMENT.vi.md)
- [Lộ trình release](docs/RELEASE_PROCESS.vi.md)
- [ONNX Runtime feasibility](docs/ONNX_RUNTIME_FEASIBILITY.md)
- [Acceptance record v1.0.0](docs/releases/v1.0.0-acceptance.md)
- [Changelog project](CHANGELOG.md)
- [Tài liệu upstream lịch sử](docs/history/README.md)

## Deployment

Project chưa cấu hình deployment application, image registry artifact, cloud account hoặc public endpoint. Các file deployment được import chỉ là template đã đổi tên và phải được review, qualification độc lập ở giai đoạn deployment sau này.

## License

Project được phát hành theo [MIT License](LICENSE).
