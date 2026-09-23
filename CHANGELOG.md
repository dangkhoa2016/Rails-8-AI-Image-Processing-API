# Changelog

## v1.1.0 — 2026-09-23

`v1.1.0` adds authenticated MobileSAM prompt segmentation while preserving the
existing deterministic image-processing and BiRefNet background-removal
contracts.

- Added authenticated `POST /images/segment` with exactly one point or box
  prompt per request and a source-sized binary PNG mask response.
- Added checksum-pinned MobileSAM encoder and prompt-mask decoder ONNX
  authorities with exact filename, byte-size, SHA-256, and port-contract
  verification before model loading.
- Added process-cached MobileSAM sessions, M2-authoritative preprocessing and
  prompt-coordinate transforms, point-token IoU selection, and box-token
  selection.
- Added ordinary stubbed controller/service coverage plus opt-in real-model
  canonical parity tests.
- Canonical M2 parity passed for preprocessing, encoder embedding, decoder
  masks, IoU predictions, low-resolution masks, positive-point output, and box
  output. The positive-point and box binary masks were pixel-identical to the
  accepted M2 evidence.
- A real authenticated multipart endpoint qualification passed in an ephemeral
  Modal CPU Function configured with 2 vCPU, a 10240 MiB memory request and
  hard limit, `WEB_CONCURRENCY=1`, and `IMAGE_AI_MAX_CONCURRENCY=1`.
  `/usr/bin/time -v` reported 773432 KiB (755.30 MiB) maximum RSS for that
  endpoint test process. This is qualification evidence for the tested
  workload, not a production-traffic, concurrency, throughput, or SLA claim.
- `v1.0.0` remains immutable; this release is normal forward history and does
  not move or rewrite the first public release.

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
