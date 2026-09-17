# Rails 8 AI Image Processing API

[![CI](https://github.com/dangkhoa2016/Rails-8-AI-Image-Processing-API/actions/workflows/ci.yml/badge.svg)](https://github.com/dangkhoa2016/Rails-8-AI-Image-Processing-API/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> Language: **English** | [Tiếng Việt](README.vi.md)

An authenticated Rails 8 API for deterministic image manipulation. It delivers
direct `ruby-vips`/libvips processing and includes a test-only ONNX Runtime CPU
feasibility spike; it does not expose AI processing in the application API.

## Project status

This repository has a deterministic authenticated image-processing API and a
local release marker.

- The Devise, JWT, refresh-token, PostgreSQL, Rack::Attack, and security test baseline remains in place.
- `GET /images/capabilities` and authenticated multipart `POST /images/process` provide deterministic Vips processing for JPEG, PNG, and WebP. The `image_processing` gem is intentionally not part of the architecture.
- A test-only ONNX Runtime CPU spike validates a checksum-pinned 105-byte sigmoid fixture. U²-NetP has checksum-pinned provenance, Ruby/Vips preprocessing, and an internal CPU inference/mask service that accepts only a verified ignored local artifact. It has no model binary in Git, API endpoint, job, GPU dependency, Python inference service, or background-compositing behavior; see [U²-NetP model provenance](docs/U2NETP_MODEL_PROVENANCE.md), [preprocessing parity](docs/U2NETP_PREPROCESSING.md), and [CPU inference and foreground masks](docs/U2NETP_INFERENCE.md).
- `v1.0.0` is the sole mutable local release marker; it does not represent a remote release or production deployment.

## Project origin

This project started from a source snapshot of:

https://github.com/dangkhoa2016/Rails-8-API-Authentication

The source snapshot was imported as a single root commit. Development, versioning, releases, CI provenance, and deployment history continue independently in this repository.

Historical upstream records are retained under [`docs/history/`](docs/history/) for attribution only; they are not this project's release or deployment authority.

## Local development

### Prerequisites

- Ruby 3.3
- Bundler
- PostgreSQL available locally
- libvips available locally (required before the direct Vips implementation phase)

Copy the local environment reference and prepare the databases:

```bash
cp .env.sample .env
bundle install
bin/rails db:prepare
```

The default development and test databases are:

```text
rails_8_ai_image_processing_api_development
rails_8_ai_image_processing_api_test
```

Run the application with `bin/dev`. Use the authenticated image routes and the
authentication routes described in `config/routes.rb` for the exact contract.

## Verification

```bash
bin/rails test
bin/rubocop
bin/brakeman --no-pager
```

## Documentation

- [Documentation index](docs/README.md)
- [Access control](docs/ACCESS_CONTROL.md)
- [JWT lifecycle](docs/JWT_LIFECYCLE.md)
- [Rate limiting](docs/RATE_LIMITING.md)
- [Deployment planning](docs/DEPLOYMENT.md)
- [Release roadmap](docs/RELEASE_PROCESS.md)
- [ONNX Runtime feasibility](docs/ONNX_RUNTIME_FEASIBILITY.md)
- [U²-NetP model provenance](docs/U2NETP_MODEL_PROVENANCE.md)
- [U²-NetP preprocessing parity](docs/U2NETP_PREPROCESSING.md)
- [U²-NetP CPU inference and foreground masks](docs/U2NETP_INFERENCE.md)
- [v1.0.0 acceptance record](docs/releases/v1.0.0-acceptance.md)
- [Project changelog](CHANGELOG.md)
- [Upstream historical records](docs/history/README.md)

## Deployment

No deployment application, image registry artifact, cloud account, or public endpoint is configured for this project. The imported deployment files are renamed templates only and must be independently reviewed and qualified in a later deployment phase.

The `v1.0.0` source release does not imply GHCR publication, and no GHCR image currently exists. Normal source-release CI verifies the pre-publication GHCR contract (`scripts/release/test_verify_ghcr_prepublication.sh`) rather than asserting that an image is published; real GHCR artifact verification remains a later image-publication gate.

## License

This project is distributed under the [MIT License](LICENSE).
