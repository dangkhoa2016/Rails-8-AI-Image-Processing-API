# U²-NetP background removal

The application exposes the authenticated endpoint:

```text
POST /images/remove-background
```

The production inference path remains Ruby-only:

```text
validated upload
  -> ruby-vips preprocessing
  -> ONNX Runtime CPU / U²-NetP
  -> foreground mask
  -> libvips alpha/background composition
  -> PNG or WebP
```

No Python inference service is used. Model conversion may use the separately pinned conversion environment documented in `U2NETP_MODEL_PROVENANCE.md`, but the runtime artifact remains local, ignored by Git, and checksum verified before ONNX Runtime loads it.

## Request contract

The endpoint requires the same authenticated active-user boundary as `/images/process`.

Multipart fields:

- `image`: required JPEG, PNG, or WebP upload.
- `format`: optional `png` or `webp`, default `png`.
- `quality`: optional for WebP, `1..100`.
- `background`: optional `#RRGGBB`; omitted means transparent output.
- `feather`: optional integer `0..20`; default `0`.

AI inference is fail-closed. `IMAGE_AI_ENABLED=true` must be explicit. A missing, invalid, or checksum-mismatched model returns the stable `503` AI-unavailable contract.

## Quality authority

Source-level tests cover geometry, alpha composition, solid-background composition, format validation, authentication, and disabled-AI behavior. They do not substitute for real-model segmentation-quality evidence.

Real-model qualification is performed with:

```bash
IMAGE_AI_ENABLED=true \
U2NETP_QUALITY_CASES=/path/to/quality-cases.json \
bundle exec ruby script/qualify_u2netp_background_removal.rb
```

The JSON manifest must contain curated real images, corresponding reference masks, and an explicit `minimum_iou` per case. A quality PASS may be claimed only from an observed run using the checksum-qualified U²-NetP ONNX artifact.
