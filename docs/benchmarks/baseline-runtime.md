# Runtime baseline (Phase 2)

Recorded: 2026-09-13 04:52 UTC
Source revision: `32e1a94` (`chore(project): establish image processing project identity`)

This is the pre-image-processing baseline for `Rails-8-AI-Image-Processing-API`.
It intentionally precedes the `ruby-vips` gem, image-processing endpoints, background
jobs, and the four-database production deployment setup.

## Environment

| Item | Observed value |
| --- | --- |
| Host | Linux 6.8.0-110-generic, x86_64; 4 CPUs; 14 GiB RAM |
| Ruby | `3.3.12` |
| Rails | `8.1.3.1` |
| PostgreSQL client | `16.15` |
| PostgreSQL server used by test/smoke | `16.15 (Ubuntu 16.15-0ubuntu0.24.04.1)` |
| Host libvips CLI | `vips-8.15.1` |
| Docker | `28.0.1` |
| Docker runtime libvips package | `libvips42t64 8.16.1-1+deb13u1` |

The current Dockerfile installs the libvips runtime library. It does **not** install the
`vips` command-line executable, so `docker run --entrypoint vips …` is expected to be
unavailable at this point. This is recorded as baseline behaviour, not changed during
Phase 2.

## Measured results

| Check | Result |
| --- | --- |
| Test suite | `321 runs, 1,582 assertions, 0 failures, 0 errors, 0 skips` in `11.593s` |
| Docker image build | PASS — `rails-8-ai-image-processing-api:phase2-baseline` |
| Docker image size | `503,994,595 bytes` (480.6 MiB) |
| Rails boot to first successful `/up` | `4.885s` (development, cold process) |
| `/up` request latency | `239.645ms` for the first probe |
| Idle Rails RSS | `115,072 KiB` (112.4 MiB) after the health probe |
| `/up` behaviour | `200 OK`, green HTML health page |
| Sign-in smoke | PASS — `POST /users/sign_in` returned `200` |
| Authenticated profile smoke | PASS — `GET /user/profile` with returned bearer token returned `200` and the expected user |

## Method

The test suite ran against the existing local PostgreSQL development/test setup. The
runtime smoke used a temporary confirmed user on the development database; its refresh
tokens, user record, response bodies, server log, and server process were removed after
the check.

The image was built from the project Dockerfile. Rails health and authentication were
measured natively in development mode because the current production configuration
requires four distinct production database URLs (`DATABASE_URL`, cache, queue, and
cable). Creating that production database topology is explicitly deferred to a later
phase, so this phase does not pretend that a production container can boot without it.

## Phase 2 acceptance

| Gate | Status |
| --- | --- |
| `P2_BASELINE` | PASS |
| `TESTS` | PASS |
| `DOCKER_BUILD` | PASS |
| `HEALTH` | PASS |
| `SIGN_IN` | PASS |
| `AUTHENTICATED_PROFILE` | PASS |
