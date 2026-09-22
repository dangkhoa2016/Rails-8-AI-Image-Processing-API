# BiRefNet CPU Qualification

This document records the CPU runtime qualification that backs the `v1.0.0`
source release of the Rails 8 AI Image Processing API. It contains stable
engineering facts only.

## Source authority

The qualification evidence is bound to the code tree used for the formal run:

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

The model is not embedded in Git. It is downloaded out-of-band and verified
against the pinned manifest (byte size and SHA-256) before runtime loading.

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

Inference runs in Ruby through the ONNX Runtime CPU backend. One ONNX session
object is loaded once and reused across the formal workload.

## Formal provider-capacity result

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

The geometry cases executed:

```text
512x512
1024x1024
1920x1080
4000x3000
```

**8192 MiB is the first tested passing tier.** It is not a proof of the exact
theoretical minimum memory requirement.

## Memory limitation

```text
Runtime /proc/meminfo reported MemTotal=8192 MiB and SwapTotal=0.
Modal did not expose the probed cgroup memory.peak telemetry.
The final VmRSS value is not used as a peak-memory claim.
```

Because the provider did not expose the cgroup `memory.peak` telemetry, this
release does not claim an exact peak-RAM number.

## Quality evidence

BiRefNet quality validation scoped to a fixed 32-image evaluation:

```text
32/32 passed
mean IoU    = 0.916778...
median IoU  = 0.941903...
minimum IoU = 0.662408...
```

These 32 images are a fixed evaluation set; they are not a universal quality
benchmark for arbitrary images.

## Evidence authorities

```text
formal Modal evidence SHA-256:
d2bef3d1a1b911ed82e1822debe9d17cd5c50acd539d822f733065e25bf5bdb4

post-review corrective evidence SHA-256:
b73eb8e8a635f9c3efb910cb110f6c6e2aadcb79ca24f50223bc7f1778c7dcba

controller/runner source supplement SHA-256:
0dda2d7823de9bf5dd4f24baf5402066bb1aa2ee83c70f7e951fa45ec2fe5676

final runner SHA-256:
7278b4aeb747868c0584e7e97c306bed543b462ca55513536ddcb722155c96f0
```

## Boundaries

This qualification is a capacity/quality result. It does not claim:

```text
production-traffic qualification
an SLA
an exact peak-RAM figure
that every 8-GiB machine will run the workload
that 8192 MiB is the exact minimum requirement
GPU acceleration
```