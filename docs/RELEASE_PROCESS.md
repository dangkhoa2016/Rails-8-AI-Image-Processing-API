# Release roadmap

## Lifecycle

This project remains **pre-1.0** until the complete public product contract is qualified. A Git tag is an immutable release record after publication; the project does not use movable stable-version markers.

Recommended milestone semantics:

```text
pre-1.0  deterministic Vips API + security/resource hardening
pre-1.0  ONNX Runtime + U²-NetP public background removal
pre-1.0  real-model quality + CPU/8 GiB qualification
pre-1.0  optional MobileSAM only if its Ruby/ONNX feasibility gate passes
v1.0.0   only after stable API, security, CI, reproducible deployment,
         model provenance, CPU qualification, and release documentation pass
```

Exact pre-1.0 version numbers are selected only when a real release candidate is ready; historical tags are never fabricated retroactively.

## Release rules

- Release from a clean `main` worktree at an exact reviewed commit.
- Run the full Rails tests, RuboCop, Brakeman, schema/repository policy checks, deterministic image qualification, and Docker cold-build gate.
- For an AI-capable release, require observed real-model background-removal quality evidence and the independently verified CPU/8 GiB resource gate.
- Verify model provenance and SHA-256 before inference qualification.
- Create the annotated release tag only after the candidate passes; do not move a published stable tag to a later commit.
- Treat GHCR publication and deployment as separate later authorities. A source release does not imply either one.
- Preserve `CHANGELOG.md` as this project's release history. `docs/history/` remains attribution-only material from the imported source baseline.

## Current authority

The repository currently contains implementation and fail-closed qualification tooling. Until the required observed qualification evidence exists, documentation must report those gates as pending rather than infer PASS from source code or test harness presence.
