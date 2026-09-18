# Changelog

## Unreleased

- Authenticated deterministic image processing for JPEG, PNG, and WebP using direct ruby-vips/libvips operations with explicit resource limits.
- Strict operation validation, metadata stripping, stateless tempfile lifecycle, image-specific rate limiting, deterministic CPU benchmark tooling, and locked Docker/release validation infrastructure.
- Checksum-pinned ONNX Runtime CPU integration and U²-NetP model provenance.
- Ruby/Vips U²-NetP preprocessing and process-wide CPU foreground inference with bounded concurrency.
- Authenticated `POST /images/remove-background` with transparent PNG/WebP output, optional solid-background composition, and fail-closed AI availability behavior.
- Real-model IoU qualification and CPU/8 GiB qualification harnesses. These entries describe tooling; observed PASS evidence remains a release gate.

No stable project release is declared by this changelog section.

Historical upstream changelog entries are available in [`docs/history/upstream-changelog.md`](docs/history/upstream-changelog.md) and do not describe releases of this project.
