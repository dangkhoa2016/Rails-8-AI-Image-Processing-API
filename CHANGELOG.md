# Changelog

## v1.0.0 — 2026-09-22

`v1.0.0` is the first public community source release of this project. The
release is published through the annotated `v1.0.0` tag and its GitHub Release;
it is not a local-only marker.

- Authenticated deterministic image processing for JPEG, PNG, and WebP using direct ruby-vips/libvips operations with explicit resource limits.
- Strict operation validation, metadata stripping, stateless tempfile lifecycle, image-specific rate limiting, deterministic CPU benchmark tooling, and locked Docker/release validation infrastructure.
- Checksum-pinned ONNX Runtime CPU integration and BiRefNet model provenance.
- Ruby/Vips BiRefNet preprocessing and process-wide CPU foreground inference with bounded concurrency.
- Authenticated `POST /images/remove-background` with transparent PNG/WebP output, optional solid-background composition, and fail-closed AI availability behavior.
- BiRefNet quality validation and a CPU runtime qualification. The formal provider-capacity workload passed in a Modal Function container configured with an 8192 MiB memory request and 8192 MiB hard limit.
- First tested passing memory tier: 8192 MiB. No exact peak-RAM claim is made because the provider did not expose cgroup `memory.peak` telemetry.
- Scope of this release: the public source contract and qualification evidence. It does not include production-traffic, SLA, GPU, or deployment claims, and it does not imply a hosted public endpoint or GHCR artifact.

Historical upstream changelog entries are available in
[`docs/history/upstream-changelog.md`](docs/history/upstream-changelog.md) and
do not describe releases of this project.