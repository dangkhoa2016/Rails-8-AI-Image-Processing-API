# Rails 8 AI Image Processing API

[![CI](https://github.com/dangkhoa2016/Rails-8-AI-Image-Processing-API/actions/workflows/ci.yml/badge.svg)](https://github.com/dangkhoa2016/Rails-8-AI-Image-Processing-API/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> Language: **English** | [Tiếng Việt](README.vi.md)

An authenticated Rails 8 API being developed for deterministic image manipulation and lightweight CPU-only AI-assisted image operations. The application currently retains the imported authentication baseline; image-processing endpoints are intentionally not available until their dedicated phases.

## Project status

This repository is in its independent project-identity phase.

- The Devise, JWT, refresh-token, PostgreSQL, Rack::Attack, and security test baseline remains in place.
- The future deterministic image stack will use `ruby-vips` directly with libvips. The `image_processing` gem is intentionally not part of the architecture.
- No AI runtime, ONNX Runtime, model artifact, GPU dependency, or Python inference service has been added.
- No release tag or production deployment is established for this project.

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

Run the application with `bin/dev`. The imported authentication routes remain the current public API surface; consult `config/routes.rb` and the authentication documentation for the exact contract.

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
- [Project changelog](CHANGELOG.md)
- [Upstream historical records](docs/history/README.md)

## Deployment

No deployment application, image registry artifact, cloud account, or public endpoint is configured for this project. The imported deployment files are renamed templates only and must be independently reviewed and qualified in a later deployment phase.

## License

This project is distributed under the [MIT License](LICENSE).
