# Docker image publication

The canonical container package for Rails 8 AI Image Processing API is:

`ghcr.io/dangkhoa2016/rails-8-ai-image-processing-api`

The release publisher builds the exact annotated release tag as a Linux
multi-platform OCI image for:

- `linux/amd64`
- `linux/arm64`

## Canonical release aliases

For `v1.0.0`, the publisher maintains these aliases for the same canonical
multi-platform OCI index:

```text
ghcr.io/dangkhoa2016/rails-8-ai-image-processing-api:v1.0.0
ghcr.io/dangkhoa2016/rails-8-ai-image-processing-api:1.0.0
ghcr.io/dangkhoa2016/rails-8-ai-image-processing-api:latest
ghcr.io/dangkhoa2016/rails-8-ai-image-processing-api:sha-<short-source-sha>
```

Normal users should prefer `v1.0.0` or another immutable release tag. Docker
automatically selects the matching platform child manifest when one of the
multi-platform aliases is pulled.

## Explicit platform aliases

GitHub Container Registry lists the child manifests of a multi-platform image as
separate package versions. To make those versions understandable in the GitHub
Packages UI, the publisher also creates two one-platform OCI aliases:

```text
ghcr.io/dangkhoa2016/rails-8-ai-image-processing-api:v1.0.0-amd64
ghcr.io/dangkhoa2016/rails-8-ai-image-processing-api:v1.0.0-arm64
```

These aliases do not rebuild the application. They wrap the exact runnable child
manifests from the canonical release index and carry explicit OCI title,
description, source, license, version, and revision annotations.

The canonical build also annotates the runnable child manifests themselves as
`linux/amd64` and `linux/arm64`. This makes direct digest pages easier to
identify when reviewing package versions.

## Provenance and SBOM entries

The publisher keeps BuildKit provenance and SBOM generation enabled. GitHub
Packages may therefore show additional untagged `sha256:...` versions whose
platform is `unknown/unknown`. Those entries are supply-chain attestations, not
runnable application images.

The release verifier distinguishes runnable AMD64/ARM64 manifests from
attestation manifests and requires exactly one runnable child for each supported
architecture.

## AI model weights are external runtime authority

The Docker image does **not** embed the qualified BiRefNet or MobileSAM model
weights. AI endpoints remain fail-closed unless:

1. the qualified model files are mounted at the expected `/models` paths; and
2. `IMAGE_AI_ENABLED=true` is configured.

This keeps the application image reproducible while preserving model-file
filename, byte-size, and SHA-256 authority separately from the container image.

## Package visibility

A newly created GHCR package is private by default even when the source
repository is public. Before announcing anonymous community pulls, change the
container package visibility to **Public** in GitHub Package settings and verify
an unauthenticated pull.

Repository visibility and package visibility are separate controls.

## Verification

The publication workflow verifies the immutable Buildx output before declaring
success. It checks:

- the annotated release tag resolves to the checked-out source commit;
- all canonical aliases resolve to the expected release revision;
- the canonical index contains the exact `linux/amd64` and `linux/arm64`
  child digests;
- `v1.0.0-amd64` contains exactly one runnable AMD64 child;
- `v1.0.0-arm64` contains exactly one runnable ARM64 child;
- OCI version/revision/title/description annotations are present.

Inspect a release manually with:

```bash
docker buildx imagetools inspect \
  ghcr.io/dangkhoa2016/rails-8-ai-image-processing-api:v1.0.0

docker buildx imagetools inspect \
  ghcr.io/dangkhoa2016/rails-8-ai-image-processing-api:v1.0.0-amd64

docker buildx imagetools inspect \
  ghcr.io/dangkhoa2016/rails-8-ai-image-processing-api:v1.0.0-arm64
```

After package visibility is Public, anonymous pulls can be verified with:

```bash
docker logout ghcr.io 2>/dev/null || true
docker pull ghcr.io/dangkhoa2016/rails-8-ai-image-processing-api:v1.0.0
```
