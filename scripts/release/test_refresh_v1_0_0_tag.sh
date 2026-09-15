#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REFRESH="${ROOT}/script/refresh_v1_0_0_tag.sh"
pass=0
fail=0
repo=""

ok() { printf 'PASS %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL %s\n' "$1" >&2; fail=$((fail + 1)); }

expect_success() {
  local label="$1"
  shift
  if "$@"; then ok "${label}"; else bad "${label}"; fi
}

expect_failure() {
  local label="$1"
  shift
  if "$@"; then bad "${label}"; else ok "${label}"; fi
}

fixture_repo() {
  repo="$(mktemp -d)"
  git -C "${repo}" init -q -b main
  git -C "${repo}" config user.name 'Release Test'
  git -C "${repo}" config user.email 'release-test@example.test'
  mkdir -p "${repo}/docs/releases"
  printf '# `v1.0.0` acceptance\n\nResolve target: `git rev-parse v1.0.0^{commit}`\n' > "${repo}/docs/releases/v1.0.0-acceptance.md"
  git -C "${repo}" add docs/releases/v1.0.0-acceptance.md
  git -C "${repo}" commit -qm 'docs: add acceptance record'
}

cleanup() {
  [[ -z "${repo}" ]] || rm -rf "${repo}"
}
trap cleanup EXIT

fixture_repo
expect_success "creates v1.0.0 on a clean main checkout" env RELEASE_REPOSITORY="${repo}" "${REFRESH}"
[[ "$(git -C "${repo}" rev-parse 'v1.0.0^{commit}' 2>/dev/null)" == "$(git -C "${repo}" rev-parse HEAD)" ]] && ok "tag resolves to HEAD" || bad "tag resolves to HEAD"

printf 'evidence refresh\n' > "${repo}/evidence.txt"
git -C "${repo}" add evidence.txt
git -C "${repo}" commit -qm 'docs: refresh evidence'
expect_success "moves only v1.0.0 to a later clean main commit" env RELEASE_REPOSITORY="${repo}" "${REFRESH}"
[[ "$(git -C "${repo}" rev-parse 'v1.0.0^{commit}' 2>/dev/null)" == "$(git -C "${repo}" rev-parse HEAD)" ]] && ok "moved tag resolves to latest HEAD" || bad "moved tag resolves to latest HEAD"

git -C "${repo}" switch -q -c corrective
printf 'validated corrective evidence\n' > "${repo}/evidence.txt"
git -C "${repo}" add evidence.txt
git -C "${repo}" commit -qm 'docs: add validated corrective evidence'
expect_failure "rejects a clean corrective branch by default" env RELEASE_REPOSITORY="${repo}" "${REFRESH}"
expect_success "allows an explicit clean descendant of main" \
  env RELEASE_REPOSITORY="${repo}" RELEASE_ALLOW_VALIDATED_DESCENDANT=1 RELEASE_BASE_REF=main "${REFRESH}"
[[ "$(git -C "${repo}" rev-parse 'v1.0.0^{commit}' 2>/dev/null)" == "$(git -C "${repo}" rev-parse HEAD)" ]] && ok "descendant tag resolves to HEAD" || bad "descendant tag resolves to HEAD"
git -C "${repo}" switch -q main

git -C "${repo}" switch -q --orphan unrelated
mkdir -p "${repo}/docs/releases"
printf '# `v1.0.0` acceptance\n\nResolve target: `git rev-parse v1.0.0^{commit}`\n' > "${repo}/docs/releases/v1.0.0-acceptance.md"
git -C "${repo}" add docs/releases/v1.0.0-acceptance.md
git -C "${repo}" commit -qm 'docs: create unrelated candidate'
expect_failure "rejects an explicit branch not descended from main" \
  env RELEASE_REPOSITORY="${repo}" RELEASE_ALLOW_VALIDATED_DESCENDANT=1 RELEASE_BASE_REF=main "${REFRESH}"
git -C "${repo}" switch -q main

git -C "${repo}" rm -q docs/releases/v1.0.0-acceptance.md
git -C "${repo}" commit -qm 'docs: remove acceptance record'
expect_failure "rejects a clean checkout without acceptance evidence" env RELEASE_REPOSITORY="${repo}" "${REFRESH}"

mkdir -p "${repo}/docs/releases"
printf '# invalid acceptance\n' > "${repo}/docs/releases/v1.0.0-acceptance.md"
git -C "${repo}" add docs/releases/v1.0.0-acceptance.md
git -C "${repo}" commit -qm 'docs: add invalid acceptance record'
expect_failure "rejects a clean checkout with invalid acceptance evidence" env RELEASE_REPOSITORY="${repo}" "${REFRESH}"

git -C "${repo}" switch -q -c topic
expect_failure "rejects a non-main branch" env RELEASE_REPOSITORY="${repo}" "${REFRESH}"

git -C "${repo}" switch -q main
printf 'dirty\n' > "${repo}/dirty.txt"
expect_failure "rejects an untracked dirty worktree" env RELEASE_REPOSITORY="${repo}" "${REFRESH}"

printf '\nMutable tag tests: %s passed, %s failed\n' "${pass}" "${fail}"
[[ "${fail}" -eq 0 ]]
