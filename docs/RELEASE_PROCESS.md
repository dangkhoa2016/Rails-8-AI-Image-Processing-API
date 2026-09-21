# Release roadmap

## Lifecycle

`v1.0.0` is this project's first public community source release. The annotated
release tag is created only after the exact accepted `main` commit passes all
mandatory qualification gates. After publication, the tag is immutable.

Semantics milestones:

```text
pre-1.0  deterministic Vips API + security/resource hardening
pre-1.0  ONNX Runtime + public background removal
pre-1.0  real-model quality + CPU/8 GiB qualification
pre-1.0  MobileSAM prompt segmentation + CPU/10 GiB endpoint qualification
v1.0.0   first public community source release
```

The final public `v1.0.0` documentation descendant is recorded in
[`releases/v1.0.0-acceptance.md`](releases/v1.0.0-acceptance.md).

## Release rules

- Release from a clean `main` worktree at an exact reviewed commit.
- Run the full Rails tests, RuboCop, Brakeman, schema/repository policy checks, deterministic image qualification, and Docker cold-build gate.
- For an AI-capable release, require observed real-model correctness/quality evidence for every newly public AI operation plus an independently verified resource qualification for the release workload.
- Verify model provenance and SHA-256 before inference qualification.
- Create the annotated `v1.0.0` tag only after the exact release candidate passes every mandatory gate; after publication, do not move the tag.
- Treat GHCR publication and deployment as separate later authorities. A source release does not imply either one.
- Preserve `CHANGELOG.md` as this project's release history. `docs/history/` remains attribution-only material from the imported source baseline.

## Current authority

`v1.0.0` is the project's first public community source release and contains
the accepted BiRefNet and MobileSAM scope. GHCR publication and production
deployment remain separate authorities.
