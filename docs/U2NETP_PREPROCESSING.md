# U²-NetP preprocessing parity

This repository has a Ruby/Vips preprocessing boundary for the pinned upstream
U²-NetP contract. It converts an already decoded `Vips::Image` into a finite
float32 tensor. It does **not** load an ONNX model or add U²-NetP inference to
the Rails application.

## Frozen contract

The reference is upstream U-2-Net commit
`ac7e1c817ecab7c7dff5ce6b1abba61cd213ff29`, specifically its
`RescaleT(320)` and `ToTensorLab(flag=0)` path.

`ImageLab::AI::U2netp::Preprocessor.call(image)` performs these steps:

1. Convert non-grayscale input to sRGB, keep its first three bands, and ignore
   alpha or extra bands. A one-band image is replicated to RGB before later
   normalization.
2. Resize independently with Vips linear interpolation to `320 × 320`. This
   intentionally does not preserve aspect ratio: it is the model contract, not
   a display-image policy.
3. Cast resized RGB samples to float, divide every sample by one global maximum
   across all three resized bands, and fail through `AI model is unavailable`
   when that maximum is non-finite or non-positive.
4. Normalize R, G, and B respectively with means `0.485`, `0.456`, `0.406`
   and standard deviations `0.229`, `0.224`, `0.225`.
5. Store values as float32 in NCHW order with shape `[1, 3, 320, 320]`.

The returned `ImageLab::AI::Tensor` owns frozen shape, byte, and value
representations. Preprocessing creates new Vips images and does not mutate the
source image.

## Pinned reference fixture

`test/fixtures/files/u2netp/preprocessing_reference.yml` is a compact
independent reference for selected tensor positions. It contains no model data
and deliberately stores five NCHW values rather than all 307,200 values. The
fixture source is deterministic multi-colour RGB at `320 × 320`; this avoids a
second image-library interpolation implementation obscuring normalization and
NCHW parity. Ruby tests separately verify the required square resize geometry
with an asymmetric source image.

The build-only reference generator pins Python `3.11.9`, NumPy `1.26.4`, and
scikit-image `0.22.0`. Regenerate the fixture from the repository root only
when the frozen reference contract is intentionally changed:

```bash
docker build -t rails-8-ai-u2netp-preprocessing:phase16 \
  -f docker/models/u2netp-preprocessing/Dockerfile \
  docker/models/u2netp-preprocessing
docker run --rm -v "$PWD":/workspace rails-8-ai-u2netp-preprocessing:phase16 \
  --output /workspace/test/fixtures/files/u2netp/preprocessing_reference.yml
```

The generator writes through a temporary sibling and atomically replaces the
fixture. It may create its output parent and publishes the file mode as `0644`.
It has no runtime relationship with Rails.

## Deliberate boundary

No runtime Python process, PTH/ONNX artifact, U²-NetP model registry entry,
model download, API route, controller, job, GPU configuration, or production
inference claim is introduced here. CI runs only the local Ruby/Vips Tensor,
preprocessor, manifest, and script-safety tests; it does not build the Python
image, download weights, execute model qualification, or write `var/models/`.
