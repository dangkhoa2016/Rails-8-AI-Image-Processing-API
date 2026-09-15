# Release roadmap

## Current version marker

`v1.0.0` is the only project version. It is a mutable local release marker:
after the required validation succeeds on a later clean `main` commit,
`script/refresh_v1_0_0_tag.sh` replaces the local annotated tag.

No remote tag, GitHub Release, image publication, or deployment is created by
this process. Resolve its exact current target with:

```sh
git rev-parse v1.0.0^{commit}
```

## Release rules

- Run the documented validation before refreshing the marker and record the
  observed results in the acceptance record.
- Refresh only local `v1.0.0` from a clean `main` checkout with
  `script/refresh_v1_0_0_tag.sh`; the tag is intentionally movable after a
  later successful validation. A validated corrective descendant may use the
  explicit `RELEASE_ALLOW_VALIDATED_DESCENDANT=1` mode, optionally selecting
  its ancestor with `RELEASE_BASE_REF` (default `main`). This exception still
  requires a clean worktree and acceptance evidence; arbitrary branches and
  candidates not descended from the base are rejected.
- Preserve `CHANGELOG.md` as this project's release history. Upstream records
  under `docs/history/` are attribution only.
- Do not infer a remote release, registry image, deployment, AI qualification,
  or production-traffic qualification from this local marker.

See [the v1.0.0 acceptance record](releases/v1.0.0-acceptance.md) for scope,
evidence, and non-evidence.
