# Recipe triển khai PostgreSQL trên Hugging Face Spaces

> **Trạng thái:** Đây là template đã đổi tên nhưng chưa cấu hình. Không có
> Hugging Face deployment nào là authority cho Rails 8 AI Image Processing API.

Thư mục này chứa Hugging Face Docker Spaces template chưa qualification. Chỉ
đặt image sau khi một project artifact được publish và xác minh độc lập:

```text
ghcr.io/<owner>/rails-8-ai-image-processing-api:<verified-version>
```

Target này không phải HA, không cung cấp SLA và không phải multi-tenant
production service.

Không dùng upstream baseline artifact làm runtime hoặc release authority của
project này.

## Cấu hình Docker Space

Tạo Docker Space và cấu hình YAML front matter trong README của Space:

```yaml
---
title: Rails 8 AI Image Processing API
sdk: docker
app_port: 7860
---
```

Wrapper expose Rails qua port `7860` và giữ provider-neutral JWT transport header là `Authorization`.

Copy `Dockerfile` trong thư mục này vào root của Docker Space repository.

## Runtime secret bắt buộc

Cấu hình dưới dạng Space secrets, tuyệt đối không commit giá trị:

```text
DATABASE_URL
CACHE_DATABASE_URL
QUEUE_DATABASE_URL
CABLE_DATABASE_URL
SECRET_KEY_BASE
CORS_ALLOWED_ORIGINS
```

Bốn database URL phải trỏ đến các PostgreSQL database phù hợp cho primary application, Solid Cache, Solid Queue và Solid Cable theo contract của frozen PostgreSQL runtime.

## Runtime secret tùy chọn

Các secret sau là optional ở Hugging Face recipe layer:

```text
DEVISE_JWT_SECRET_KEY
RAILS_MASTER_KEY
```

Ứng dụng resolve JWT signing secret thông qua credential/environment fallback chain đã cấu hình, vì vậy `DEVISE_JWT_SECRET_KEY` không được coi là bắt buộc ở Space recipe.

`RAILS_MASTER_KEY` là bắt buộc khi Rails runtime cần giải mã `config/credentials.yml.enc`. Tuyệt đối không commit Rails master key, database password, token hoặc decrypted credential payload vào Space repository.

Space variables khuyến nghị:

```text
DEVISE_MAILER_SENDER=noreply@example.invalid
RAILS_LOG_TO_STDOUT=true
JWT_AUTH_HEADER=Authorization
```

Thiết lập `CORS_ALLOWED_ORIGINS` thành origin thực tế của Space thông qua secret/environment configuration bắt buộc của deployment.

## Startup contract

PostgreSQL baseline image cung cấp `/rails/bin/docker-entrypoint`. Hugging Face wrapper cố ý giữ command shape tương thích baseline:

```text
./bin/thrust ./bin/rails server
```

với `PORT=7860`.

Command shape này cho phép inherited entrypoint chạy `./bin/rails db:prepare` trước khi start server. Không thêm custom Rails server arguments làm entrypoint không còn nhận diện được server command, trừ khi startup contract đã được re-verify.

## Health và acceptance

Rails lắng nghe tại `0.0.0.0:7860`; built-in health endpoint là `/up`.

Sau khi Space chạy, thực hiện full release smoke bằng test credential chỉ tồn tại lúc runtime:

```bash
API_BASE_URL='https://<space-host>' \
SMOKE_EMAIL="$SMOKE_EMAIL" \
SMOKE_PASSWORD="$SMOKE_PASSWORD" \
JWT_AUTH_HEADER='Authorization' \
  ../../scripts/release/smoke_deployment.sh
```

Health-only PASS chỉ là diagnostic evidence, không đủ release Gate 5. Full acceptance yêu cầu `/up`, `/users/sign_in` và `/user/profile` đều PASS.
