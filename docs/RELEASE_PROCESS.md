# Release roadmap

Rails 8 AI Image Processing API has no published release yet. Its versioning
and release evidence start independently from the imported root commit.

## Planned milestones

- `v0.1.0`: authenticated deterministic image-processing API backed directly by ruby-vips and libvips.
- `v0.2.0`: hardened and benchmarked deterministic image processing.
- `v0.3.0`: CPU-only U²-NetP background removal, if ONNX Runtime qualification succeeds.
- `v0.4.0`: optional interactive segmentation only if the MobileSAM Ruby/ONNX feasibility gate passes.
- `v1.0.0`: only after API stability, security boundaries, CI, CPU/RAM qualification, deployment reproducibility, and model provenance are complete.

## Release rules

- Create no tag or GitHub release until the relevant milestone is implemented and independently verified.
- Use an immutable semantic-version tag on the exact reviewed `main` commit.
- Record observed test, security, benchmark, and deployment evidence with the release; do not claim evidence that has not been collected.
- Preserve `CHANGELOG.md` as this project's release history. Upstream records under `docs/history/` are attribution only.
