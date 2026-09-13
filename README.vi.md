# Rails 8 AI Image Processing API

[![CI](https://github.com/dangkhoa2016/Rails-8-AI-Image-Processing-API/actions/workflows/ci.yml/badge.svg)](https://github.com/dangkhoa2016/Rails-8-AI-Image-Processing-API/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> Ngôn ngữ: [English](README.md) | **Tiếng Việt**

Một Rails 8 API có xác thực, đang được phát triển cho xử lý ảnh xác định và các thao tác AI nhẹ, chạy CPU. Ứng dụng hiện giữ nguyên baseline xác thực được import; các endpoint xử lý ảnh được chủ động để sang những giai đoạn chuyên biệt tiếp theo.

## Trạng thái project

Repository đang ở giai đoạn thiết lập nhận diện độc lập.

- Baseline Devise, JWT, refresh token, PostgreSQL, Rack::Attack và security test vẫn được giữ nguyên.
- Stack xử lý ảnh xác định trong tương lai sẽ dùng trực tiếp `ruby-vips` và libvips. Gem `image_processing` không thuộc kiến trúc này.
- Chưa thêm AI runtime, ONNX Runtime, model artifact, GPU dependency hoặc Python inference service.
- Project chưa có release tag hay deployment production được xác nhận.

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

Chạy ứng dụng bằng `bin/dev`. Các route xác thực được import vẫn là API public hiện tại; xem `config/routes.rb` và tài liệu xác thực để biết contract chính xác.

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
- [Changelog project](CHANGELOG.md)
- [Tài liệu upstream lịch sử](docs/history/README.md)

## Deployment

Project chưa cấu hình deployment application, image registry artifact, cloud account hoặc public endpoint. Các file deployment được import chỉ là template đã đổi tên và phải được review, qualification độc lập ở giai đoạn deployment sau này.

## License

Project được phát hành theo [MIT License](LICENSE).
