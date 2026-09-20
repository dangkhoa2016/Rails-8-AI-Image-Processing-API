# Release roadmap

## Lifecycle

`v1.0.0` is this project's finalized first public community source release. A
Git tag is an immutable release record after publication; the project does not
move a published stable-version tag to a later commit for cosmetic cleanup.

Semantics milestones:

```text
pre-1.0  deterministic Vips API + security/resource hardening
pre-1.0  ONNX Runtime + public background removal
pre-1.0  real-model quality + CPU/8 GiB qualification
v1.0.0   first public community source release (finalized 2026-09-22)
```

The final public `v1.0.0` documentation descendant is recorded in
[`releases/v1.0.0-acceptance.md`](releases/v1.0.0-acceptance.md).

## Release rules

- Release from a clean `main` worktree at an exact reviewed commit.
- Run the full Rails tests, RuboCop, Brakeman, schema/repository policy checks, deterministic image qualification, and Docker cold-build gate.
- For an AI-capable release, require observed real-model background-removal quality evidence and the independently verified CPU/8 GiB resource gate.
- Verify model provenance and SHA-256 before inference qualification.
- Create the annotated release tag only after the candidate passes; once published, do not move the tag.
- Treat GHCR publication and deployment as separate later authorities. A source release does not imply either one.
- Preserve `CHANGELOG.md` as this project's release history. `docs/history/` remains attribution-only material from the imported source baseline.

## Current authority

`v1.0.0` is declared as a public community source release with the immutable
lock set. Future code corrections use normal forward history and an
appropriate new version when warranted; they do not force-rewrite `main` or
move `v1.0.0`.