#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPOSITORY="${RELEASE_REPOSITORY:-${SCRIPT_ROOT}}"
REPOSITORY="$(git -C "${REPOSITORY}" rev-parse --show-toplevel)"
ACCEPTANCE="${REPOSITORY}/docs/releases/v1.0.0-acceptance.md"
TAG="v1.0.0"

[[ "$(git -C "${REPOSITORY}" branch --show-current)" == "main" ]] || {
  printf 'FAIL refresh requires main\n' >&2
  exit 1
}
[[ -z "$(git -C "${REPOSITORY}" status --porcelain --untracked-files=all)" ]] || {
  printf 'FAIL refresh requires a clean worktree\n' >&2
  exit 1
}
[[ -s "${ACCEPTANCE}" ]] || {
  printf 'FAIL missing acceptance record\n' >&2
  exit 1
}
grep -Fq '`v1.0.0`' "${ACCEPTANCE}" || {
  printf 'FAIL acceptance record does not name v1.0.0\n' >&2
  exit 1
}
grep -Fq 'git rev-parse v1.0.0^{commit}' "${ACCEPTANCE}" || {
  printf 'FAIL acceptance record lacks tag-target resolve command\n' >&2
  exit 1
}

TARGET="$(git -C "${REPOSITORY}" rev-parse HEAD)"
TIMESTAMP="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
git -C "${REPOSITORY}" tag -fa "${TAG}" -m "Mutable local release marker ${TAG}

Target: ${TARGET}
Refreshed: ${TIMESTAMP}

This tag is intentionally movable after successful validation."
printf 'PASS %s -> %s\n' "${TAG}" "$(git -C "${REPOSITORY}" rev-parse "${TAG}^{commit}")"
