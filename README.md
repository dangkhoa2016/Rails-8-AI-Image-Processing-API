# Rails 8 AI Image Processing API

[![CI](https://github.com/dangkhoa2016/Rails-8-AI-Image-Processing-API/actions/workflows/ci.yml/badge.svg)](https://github.com/dangkhoa2016/Rails-8-AI-Image-Processing-API/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> Language: **English** | [Tiếng Việt](README.vi.md)

An authenticated Rails 8 API for deterministic image manipulation and
lightweight CPU-only AI-assisted image processing.

- Deterministic transforms use direct `ruby-vips`/libvips operations.
- AI background removal runs BiRefNet locally through the ONNX Runtime CPU
  backend inside Ruby and produces a foreground mask that libvips uses for
  composition.

`v1.0.0` is this project's first public source release. `v1.1.0` adds the
MobileSAM segmentation API. See
[`docs/releases/v1.1.0-acceptance.md`](docs/releases/v1.1.0-acceptance.md) for
the new release scope, while the immutable `v1.0.0` record remains at
[`docs/releases/v1.0.0-acceptance.md`](docs/releases/v1.0.0-acceptance.md).

## Project status

`v1.1.0` is the current source-release candidate; `v1.0.0` remains the immutable first public community source release.

- Devise, JWT, refresh-token rotation, PostgreSQL, Rack::Attack, and the
  existing security baseline are the authentication foundation.
- `GET /images/capabilities` and authenticated multipart `POST /images/process`
  provide deterministic JPEG, PNG, and WebP processing with explicit
  input/output/resource limits.
- Authenticated `POST /images/remove-background` is the AI background-removal
  contract.
- Authenticated `POST /images/segment` is the MobileSAM prompt-segmentation
  contract. It accepts one point or box prompt and returns a source-sized
  binary PNG mask.
- AI is fail-closed and must be explicitly enabled with
  `IMAGE_AI_ENABLED=true`.
- BiRefNet and MobileSAM ONNX artifacts are not committed to Git. Their
  provenance, filenames, tensor contracts, byte sizes, and SHA-256 authorities
  are pinned in `config/models/` and verified before runtime loading.
- Python is not part of production inference. Ruby/Vips performs preprocessing
  and composition; the ONNX Runtime CPU backend performs model inference.
- A formal CPU runtime qualification passed in a provider-managed Modal
  Function container configured with an 8192 MiB memory request and 8192 MiB
  hard limit. This is a capacity qualification, not a production-traffic or
  SLA claim. See [`docs/BIREFNET_CPU_QUALIFICATION.md`](docs/BIREFNET_CPU_QUALIFICATION.md).
- No production deployment, hosted public endpoint, or GHCR artifact is
  implied by this source repository.

The `image_processing` gem is intentionally not part of this architecture.

## Project origin

This project started from a source snapshot of:

https://github.com/dangkhoa2016/Rails-8-API-Authentication

The source snapshot was imported as a single root commit. Development,
versioning, release, CI, and deployment authority are independent in this
repository. Historical upstream records under [`docs/history/`](docs/history/)
are retained for attribution only.

## Local development

### Prerequisites

- Ruby 3.3
- Bundler
- PostgreSQL
- libvips

Prepare the application:

```bash
cp .env.sample .env
bundle install
bin/rails db:prepare
```

For deterministic image processing, no AI model is required. For local BiRefNet
inference, install the checksum-qualified model using the provenance workflow
and then opt in explicitly:

```bash
script/models/fetch_birefnet
IMAGE_AI_ENABLED=true bin/dev
```

The default BiRefNet artifact authority is documented in
[`docs/BIREFNET_CPU_QUALIFICATION.md`](docs/BIREFNET_CPU_QUALIFICATION.md).

## Public image endpoints

```text
GET  /images/capabilities
POST /images/process
POST /images/remove-background
POST /images/segment
```

All image endpoints require an authenticated active user.

`POST /images/process` is the deterministic Vips pipeline. It requires an
`operations` parameter and accepts JPEG, PNG, or WebP input.

`POST /images/remove-background` accepts JPEG, PNG, or WebP input and returns
PNG or WebP. Omitting `background` returns transparent output;
`background=#RRGGBB` performs deterministic solid-background composition with
libvips. Optional parameters: `feather` (0–20), `format` (`png`/`webp`), and
`quality` (1–100). The default foreground-mask provider in this endpoint is
BiRefNet.

`POST /images/segment` accepts JPEG, PNG, or WebP input plus exactly one JSON
prompt. A point prompt uses `{"type":"point","x":...,"y":...,"label":0|1}`;
a box prompt uses `{"type":"box","x0":...,"y0":...,"x1":...,"y1":...}`. The response is a
single-band binary PNG mask at the autorotated source-image geometry. The
endpoint uses MobileSAM encoder + prompt-mask decoder ONNX sessions cached once
per process, with one encoder inference and one decoder inference per request.

AI is fail-closed: when `IMAGE_AI_ENABLED` is not `true`, the endpoint returns
`503 AI model is unavailable`.

## Verification

```bash
bin/rails test
bin/rubocop
bin/brakeman --no-pager
```

BiRefNet quality validation and the 8-GiB CPU runtime qualification are
documented separately in
[`docs/BIREFNET_CPU_QUALIFICATION.md`](docs/BIREFNET_CPU_QUALIFICATION.md).

## Documentation

- [Documentation index](docs/README.md)
- [Image processing contract](docs/IMAGE_PROCESSING_CONTRACT.md)
- [ONNX Runtime feasibility](docs/ONNX_RUNTIME_FEASIBILITY.md)
- [BiRefNet CPU qualification](docs/BIREFNET_CPU_QUALIFICATION.md)
- [v1.1.0 acceptance record](docs/releases/v1.1.0-acceptance.md)
- [v1.0.0 acceptance record](docs/releases/v1.0.0-acceptance.md)
- [Release roadmap](docs/RELEASE_PROCESS.md)
- [Project changelog](CHANGELOG.md)

## Deployment

This repository does not establish a hosted production deployment, a live
public endpoint, or an image registry artifact. Deployment is a separate
follow-up activity outside the source-release scope.

## License

This project is distributed under the [MIT License](LICENSE).
