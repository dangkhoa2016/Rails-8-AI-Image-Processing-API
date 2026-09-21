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
- Authenticated `POST /images/segment` using MobileSAM with exactly one point or box prompt per request and a source-sized binary PNG mask response.
- Checksum-pinned MobileSAM encoder and prompt-mask decoder ONNX authorities with exact filename, byte-size, SHA-256, and port-contract verification before model loading.
- Process-cached MobileSAM sessions with M2-authoritative preprocessing, prompt-coordinate transforms, point-token IoU selection, and box-token selection.
- Canonical M2 parity passed for preprocessing, encoder embedding, decoder masks, IoU predictions, low-resolution masks, positive-point output, and box output. Positive-point and box binary masks were pixel-identical to the accepted M2 evidence.
- A real authenticated multipart MobileSAM endpoint qualification passed in an ephemeral Modal CPU Function configured with 2 vCPU and a 10240 MiB memory request/hard limit, with `WEB_CONCURRENCY=1`, `IMAGE_AI_MAX_CONCURRENCY=1`, and GPU disabled. `/usr/bin/time -v` reported 773432 KiB (755.30 MiB) maximum RSS for that endpoint test process.
- The `v1.0.0` publication requires the production Docker cold-build CI gate to pass on the exact public `main` commit.
- Scope of this release: the public source contract and qualification evidence. It does not include production-traffic, SLA, GPU, or deployment claims, and it does not imply a hosted public endpoint or GHCR artifact.

Historical upstream changelog entries are available in
[`docs/history/upstream-changelog.md`](docs/history/upstream-changelog.md) and
do not describe releases of this project.
