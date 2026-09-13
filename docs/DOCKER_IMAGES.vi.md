# Chính sách Docker image

Chưa có Docker image nào được phát hành hoặc qualification cho Rails 8 AI Image
Processing API. Dockerfile trong repository là baseline đã import; khi một quy
trình release sau này cho phép publish, image sẽ dùng tên
`dangkhoa2016/rails-8-ai-image-processing-api`.

Trước khi publish image, project phải xác minh authentication baseline Rails,
native libvips runtime khi được thêm, security checks và CPU/RAM qualification
liên quan. Không coi upstream container tag, registry hoặc deployment result là
artifact của project này.
