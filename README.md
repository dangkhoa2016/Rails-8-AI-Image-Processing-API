# Rails 8 AI Image Processing API

[![CI](https://github.com/dangkhoa2016/Rails-8-AI-Image-Processing-API/actions/workflows/ci.yml/badge.svg)](https://github.com/dangkhoa2016/Rails-8-AI-Image-Processing-API/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> Language: **English** | [Tiếng Việt](README.vi.md)

An authenticated Rails 8 API for deterministic image manipulation and lightweight CPU-only AI-assisted image processing. Deterministic transforms use direct `ruby-vips`/libvips. U²-NetP inference runs locally through ONNX Runtime and produces a foreground mask that libvips uses for background removal.

## Project status

The project is intentionally **pre-1.0** while the AI and deployment qualification gates are completed.

- Devise, JWT, refresh-token rotation, PostgreSQL, Rack::Attack, and the existing security baseline remain in place.
- `GET /images/capabilities` and authenticated multipart `POST /images/process` provide deterministic JPEG, PNG, and WebP processing with explicit input/output/resource limits.
- Authenticated `POST /images/remove-background` provides the public U²-NetP background-removal contract. AI is fail-closed and must be explicitly enabled with `IMAGE_AI_ENABLED=true`.
- The U²-NetP ONNX model is not committed to Git. Its provenance, conversion recipe, filename, tensor contract, and SHA-256 authority are pinned and verified before runtime loading.
- Python is not part of production inference. Ruby/Vips performs preprocessing and composition; ONNX Runtime CPU performs model inference.
- Real-model segmentation-quality evidence and the CPU/8 GiB runtime qualification remain explicit release gates. Their harnesses are committed, but this source tree does not claim those gates have been observed as PASS.
- No production deployment or GHCR artifact is implied by the source repository.

The `image_processing` gem is intentionally not part of this architecture.

## Project origin

This project started from a source snapshot of:

https://github.com/dangkhoa2016/Rails-8-API-Authentication

The source snapshot was imported as a single root commit. Development, versioning, release, CI, and deployment authority are independent in this repository. Historical upstream records under [`docs/history/`](docs/history/) are retained for attribution only.

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

For deterministic image processing, no AI model is required. For local U²-NetP inference, install the checksum-qualified model using the provenance workflow and then opt in explicitly:

```bash
IMAGE_AI_ENABLED=true bin/dev
```

The default U²-NetP artifact authority is documented in [`docs/U2NETP_MODEL_PROVENANCE.md`](docs/U2NETP_MODEL_PROVENANCE.md).

## Public image endpoints

```text
GET  /images/capabilities
POST /images/process
POST /images/remove-background
```

All image endpoints require an authenticated active user.

`POST /images/remove-background` accepts JPEG, PNG, or WebP input and returns PNG or WebP. Omitting `background` returns transparent output; `background=#RRGGBB` performs deterministic solid-background composition with libvips.

## Verification

```bash
bin/rails test
bin/rubocop
bin/brakeman --no-pager
```

Real-model quality and 8 GiB CPU qualification use separate fail-closed harnesses documented below; their presence is not itself PASS evidence.

## Documentation

- [Documentation index](docs/README.md)
- [Image processing contract](docs/IMAGE_PROCESSING_CONTRACT.md)
- [ONNX Runtime feasibility](docs/ONNX_RUNTIME_FEASIBILITY.md)
- [U²-NetP model provenance](docs/U2NETP_MODEL_PROVENANCE.md)
- [U²-NetP preprocessing](docs/U2NETP_PREPROCESSING.md)
- [U²-NetP CPU inference](docs/U2NETP_INFERENCE.md)
- [U²-NetP background removal](docs/U2NETP_BACKGROUND_REMOVAL.md)
- [U²-NetP CPU / 8 GiB qualification](docs/benchmarks/u2netp-cpu-8gb.md)
- [Release roadmap](docs/RELEASE_PROCESS.md)
- [Project changelog](CHANGELOG.md)

## Deployment

No production deployment, image registry artifact, or public endpoint is established by this source tree. Deployment qualification is a later gate after local AI quality/resource qualification.

## License

This project is distributed under the [MIT License](LICENSE).
