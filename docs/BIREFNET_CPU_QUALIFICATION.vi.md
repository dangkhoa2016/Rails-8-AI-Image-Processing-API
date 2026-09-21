# BiRefNet CPU Qualification (Tiếng Việt)

Tài liệu này ghi lại CPU runtime qualification làm nền cho v1.0.0 source
release của Rails 8 AI Image Processing API. Nội dung chỉ bao gồm các sự kiện
kỹ thuật ổn định.

## Nguồn authority

Bằng chứng qualification được gắn với code tree dùng cho formal run:

```text
qualified commit: 89fa0965205376738dfcc79a1018dd97b0cb4a17
qualified tree:   867b1f8498dd3c30a1d607523236c515ae14250d
```

## Model

```text
model:        BiRefNet-general-epoch_244.onnx
bytes:        972666916
sha256:       58f621f00f5d756097615970a88a791584600dcf7c45b18a0a6267535a1ebd3c
upstream:     https://github.com/ZhengPeng7/BiRefNet (MIT)
input:        input_image [1,3,1024,1024] tensor(float)
output:       output_image [1,1,1024,1024] tensor(float)
```

Model không được nhúng trong Git. Model được tải out-of-band và xác minh theo
manifest đã pin (byte size và SHA-256) trước khi load runtime.

## Runtime

```text
Ruby 3.3.12
Bundler 2.5.22
libvips 8.15.1
onnxruntime 0.11.7
ruby-vips 2.3.0
CPU only
IMAGE_AI_MAX_CONCURRENCY=1
```

Inference chạy trong Ruby qua ONNX Runtime CPU backend. Một ONNX session được
load một lần và tái sử dụng trong suốt formal workload.

## Kết quả formal provider-capacity

```text
provider:                       Modal (provider-managed Function container)
CPU request / hard limit:       2.0 / 2.0 cores
memory request / hard limit:    8192 / 8192 MiB
GPU:                            none
warmup:                         1
sequential:                     8
geometries:                     4
model load count:               1
session reuse:                  PASS
swap observed:                  none
formal result:                  PASS
```

Các geometry cases đã chạy:

```text
512x512
1024x1024
1920x1080
4000x3000
```

**8192 MiB là tier passing đầu tiên đã được kiểm thử.** Đây không phải bằng
chứng về exact theoretical minimum memory requirement.

## Giới hạn về bộ nhớ

```text
Runtime /proc/meminfo báo MemTotal=8192 MiB và SwapTotal=0.
Modal không expose cgroup memory.peak telemetry.
Giá trị final VmRSS không được dùng làm peak-memory claim.
```

Vì provider không expose cgroup `memory.peak` telemetry, release này không
claim một con số peak-RAM chính xác.

## Bằng chứng quality

BiRefNet quality validation giới hạn trong fixed 32-image evaluation:

```text
32/32 passed
mean IoU    = 0.916778...
median IoU  = 0.941903...
minimum IoU = 0.662408...
```

32 ảnh này là fixed evaluation set; không phải universal quality benchmark
cho mọi loại ảnh.

## Evidence authorities

```text
formal Modal evidence SHA-256:
d2bef3d1a1b911ed82e1822debe9d17cd5c50acd539d822f733065e25bf5bdb4

accepted evidence SHA-256:
b73eb8e8a635f9c3efb910cb110f6c6e2aadcb79ca24f50223bc7f1778c7dcba

controller/runner source supplement SHA-256:
0dda2d7823de9bf5dd4f24baf5402066bb1aa2ee83c70f7e951fa45ec2fe5676

final runner SHA-256:
7278b4aeb747868c0584e7e97c306bed543b462ca55513536ddcb722155c96f0
```

## Boundaries

Qualification này là kết quả capacity/quality. Không claim:

```text
production-traffic qualification
một SLA
một con số peak-RAM chính xác
rằng mọi máy 8-GiB đều chạy được workload
rằng 8192 MiB là yêu cầu bộ nhớ tối thiểu chính xác
GPU acceleration
```