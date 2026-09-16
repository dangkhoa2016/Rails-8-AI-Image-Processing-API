#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

pass=0
fail=0

ok() { printf 'PASS %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL %s\n' "$1" >&2; fail=$((fail + 1)); }

expect_success() {
  local label="$1"
  shift
  if "$@"; then ok "$label"; else bad "$label"; fi
}

expect_failure() {
  local label="$1"
  shift
  if "$@"; then bad "$label"; else ok "$label"; fi
}

copy_repository_fixture() {
  local fixture_root="$1"
  local repository="${fixture_root}/repository"

  cp -R "${SCRIPT_DIR}/../.." "${repository}"
  rm -rf "${repository}/.git"
  git -C "${repository}" init --quiet
  git -C "${repository}" config user.email test@example.com
  git -C "${repository}" config user.name 'Release helper test'
  git -C "${repository}" add deploy
  git -C "${repository}" commit --quiet -m 'test: prepare release fixture' -m '- Track deploy files for release verifier fixtures.'
}

verify_rejects_unavailable_git_metadata() {
  local fixture output rc
  fixture="$(mktemp -d)"
  trap 'rm -rf "${fixture}"' RETURN

  copy_repository_fixture "${fixture}"
  printf '#!/usr/bin/env bash\nexit 0\n' > "${fixture}/repository/deploy/beam/test_deploy.sh"
  chmod +x "${fixture}/repository/deploy/beam/test_deploy.sh"

  set +e
  output="$(GIT_DIR=/definitely/missing bash "${fixture}/repository/scripts/release/verify_repository.sh" 2>&1)"
  rc=$?
  set -e

  rm -rf "${fixture}"
  trap - RETURN

  [[ "${rc}" -ne 0 ]] && ! grep -Fxq 'PASS repository release contract' <<<"${output}"
}

verify_rejects_tracked_deploy_file_enumeration_failure() {
  local fixture fake_bin real_git output rc
  fixture="$(mktemp -d)"
  trap 'rm -rf "${fixture}"' RETURN
  fake_bin="${fixture}/fake-bin"
  real_git="$(command -v git)"

  copy_repository_fixture "${fixture}"
  printf '#!/usr/bin/env bash\nexit 0\n' > "${fixture}/repository/deploy/beam/test_deploy.sh"
  chmod +x "${fixture}/repository/deploy/beam/test_deploy.sh"
  mkdir -p "${fake_bin}"
  cat > "${fake_bin}/git" <<'SH'
#!/usr/bin/env sh
if [ "$1" = "ls-files" ] && [ "$2" = "--" ] && [ "$3" = "deploy" ]; then
  echo 'forced ls-files failure' >&2
  exit 42
fi

exec "${REAL_GIT_BIN}" "$@"
SH
  chmod +x "${fake_bin}/git"

  set +e
  output="$(PATH="${fake_bin}:${PATH}" REAL_GIT_BIN="${real_git}" bash "${fixture}/repository/scripts/release/verify_repository.sh" 2>&1)"
  rc=$?
  set -e

  rm -rf "${fixture}"
  trap - RETURN

  [[ "${rc}" -ne 0 ]] &&
    grep -Fxq 'FAIL unable to enumerate tracked deploy files' <<<"${output}" &&
    ! grep -Fxq 'PASS repository release contract' <<<"${output}"
}

verify_rejects_python_alias_without_python3() {
  local fixture fake_bin real_python3 bash_bin executable output rc
  fixture="$(mktemp -d)"
  trap 'rm -rf "${fixture}"' RETURN
  fake_bin="${fixture}/fake-bin"
  real_python3="$(command -v python3)"
  bash_bin="$(command -v bash)"

  copy_repository_fixture "${fixture}"
  mkdir -p "${fake_bin}"
  for executable in git grep ruby dirname bash; do
    ln -s "$(command -v "${executable}")" "${fake_bin}/${executable}"
  done
  cat > "${fake_bin}/python" <<SH
#!/usr/bin/env bash
exec "${real_python3}" "\$@"
SH
  chmod +x "${fake_bin}/python"

  set +e
  output="$(PATH="${fake_bin}" "${bash_bin}" "${fixture}/repository/scripts/release/verify_repository.sh" 2>&1)"
  rc=$?
  set -e

  rm -rf "${fixture}"
  trap - RETURN

  [[ "${rc}" -ne 0 ]] &&
    grep -Fxq 'FAIL python3 is required for repository release verification' <<<"${output}" &&
    ! grep -Fxq 'PASS repository release contract' <<<"${output}"
}

REV="6897c773ec1321401e52c21c63870a72d01ca349"

MULTIARCH_OK="$(cat <<JSON
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.index.v1+json",
  "annotations": {"org.opencontainers.image.revision": "${REV}"},
  "manifests": [
    {"digest":"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","platform":{"os":"linux","architecture":"amd64"}},
    {"digest":"sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","platform":{"os":"linux","architecture":"arm64"}}
  ]
}
JSON
)"

MULTIARCH_MISSING_ARM="$(jq ' .manifests |= map(select(.platform.architecture != "arm64")) ' <<<"${MULTIARCH_OK}")"
MULTIARCH_WRONG_REV="$(jq '.annotations["org.opencontainers.image.revision"] = "deadbeef"' <<<"${MULTIARCH_OK}")"
MULTIARCH_DUP_AMD64="$(jq '.manifests += [.manifests[0]]' <<<"${MULTIARCH_OK}")"

AMD64_OK="$(cat <<JSON
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.index.v1+json",
  "annotations": {"org.opencontainers.image.revision": "${REV}"},
  "manifests": [
    {"digest":"sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","platform":{"os":"linux","architecture":"amd64"}}
  ]
}
JSON
)"

expect_success "multiarch index accepts amd64+arm64" assert_multiarch_index_json "${MULTIARCH_OK}" "${REV}"
expect_failure "multiarch index rejects missing arm64" assert_multiarch_index_json "${MULTIARCH_MISSING_ARM}" "${REV}"
expect_failure "multiarch index rejects revision mismatch" assert_multiarch_index_json "${MULTIARCH_WRONG_REV}" "${REV}"
expect_failure "multiarch index rejects duplicate amd64" assert_multiarch_index_json "${MULTIARCH_DUP_AMD64}" "${REV}"
expect_success "single-platform alias accepts linux/amd64" assert_single_platform_index_json "${AMD64_OK}" linux amd64 "${REV}"
expect_failure "single-platform alias rejects wrong requested arch" assert_single_platform_index_json "${AMD64_OK}" linux arm64 "${REV}"

[[ "$(normalize_base_url 'https://example.test/')" == "https://example.test" ]] && ok "base URL strips trailing slash" || bad "base URL strips trailing slash"

CI_FILE="${SCRIPT_DIR}/../../.github/workflows/ci.yml"
if grep -Eq '^  push:$' "${CI_FILE}" &&
   grep -Eq '^    branches: \[main\]$|^      - main$' "${CI_FILE}"; then
  ok "CI runs on push to main"
else
  bad "CI runs on push to main"
fi

if grep -Fq 'github.event.pull_request.base.sha' "${CI_FILE}" &&
   grep -Fq 'github.event.before' "${CI_FILE}" &&
   grep -Fq 'git rev-parse HEAD^' "${CI_FILE}" &&
   grep -Fq 'git merge-base --is-ancestor' "${CI_FILE}" &&
   grep -Fq 'BASE_SHA=HEAD' "${CI_FILE}"; then
  ok "repository policy resolves incremental and rewritten-history bases"
else
  bad "repository policy resolves incremental and rewritten-history bases"
fi

RELEASE_PROCESS_EN="${SCRIPT_DIR}/../../docs/RELEASE_PROCESS.md"
RELEASE_PROCESS_VI="${SCRIPT_DIR}/../../docs/RELEASE_PROCESS.vi.md"
if grep -Fq '# Release roadmap' "${RELEASE_PROCESS_EN}" &&
   grep -Fq '`v1.0.0`' "${RELEASE_PROCESS_EN}" &&
   grep -Fq 'mutable local release marker' "${RELEASE_PROCESS_EN}" &&
   grep -Fq '# Lộ trình release' "${RELEASE_PROCESS_VI}" &&
   grep -Fq '`v1.0.0`' "${RELEASE_PROCESS_VI}" &&
   grep -Fq 'mốc release local có thể di chuyển' "${RELEASE_PROCESS_VI}"; then
  ok "release roadmap declares the mutable local v1.0.0 marker"
else
  bad "release roadmap declares the mutable local v1.0.0 marker"
fi

HF_DOCKERFILE="${SCRIPT_DIR}/../../deploy/huggingface/Dockerfile"
HF_README_EN="${SCRIPT_DIR}/../../deploy/huggingface/README.md"
HF_README_VI="${SCRIPT_DIR}/../../deploy/huggingface/README.vi.md"
if grep -Fq 'ARG RAILS_IMAGE=ghcr.io/<owner>/rails-8-ai-image-processing-api:unpublished' "${HF_DOCKERFILE}" &&
   grep -Fq 'unconfigured, renamed template' "${HF_README_EN}" &&
   grep -Fq '<verified-version>' "${HF_README_EN}" &&
   grep -Fq 'template đã đổi tên nhưng chưa cấu hình' "${HF_README_VI}" &&
   grep -Fq '<verified-version>' "${HF_README_VI}"; then
  ok "Hugging Face template has no upstream runtime authority"
else
  bad "Hugging Face template has no upstream runtime authority"
fi

SMOKE_SCRIPT="${SCRIPT_DIR}/smoke_deployment.sh"
if [[ -x "${SMOKE_SCRIPT}" ]]; then
  if API_BASE_URL=https://example.test SMOKE_EMAIL=user@example.test "${SMOKE_SCRIPT}" --validate-only >/dev/null 2>&1; then
    bad "smoke verifier rejects incomplete credentials"
  else
    ok "smoke verifier rejects incomplete credentials"
  fi
fi

expect_success "mutable local v1.0.0 tag contract" bash "${SCRIPT_DIR}/test_refresh_v1_0_0_tag.sh"

expect_success "repository verifier rejects unavailable Git metadata without a PASS marker" \
  verify_rejects_unavailable_git_metadata

expect_success "repository verifier rejects tracked deploy-file enumeration failure without a PASS marker" \
  verify_rejects_tracked_deploy_file_enumeration_failure

expect_success "repository verifier requires python3 instead of a python alias" \
  verify_rejects_python_alias_without_python3

if grep -Fq 'python3' "${CI_FILE}"; then
  ok "CI declares python3 for host validation"
else
  bad "CI declares python3 for host validation"
fi

verify_canonical_runner_contract() {
  local dockerfile="${SCRIPT_DIR}/../../docker/release-gate/Dockerfile"
  local compose_file="${SCRIPT_DIR}/../../docker/release-gate/compose.yml"
  local dockerignore="${SCRIPT_DIR}/../../.dockerignore"
  local gitignore="${SCRIPT_DIR}/../../.gitignore"

  [[ -s "${dockerfile}" ]] &&
    [[ -s "${compose_file}" ]] &&
    grep -Eq '^FROM ruby:3\.3\.12-slim@sha256:[0-9a-f]{64}$' "${dockerfile}" &&
    grep -Fxq 'COPY Gemfile Gemfile.lock ./' "${dockerfile}" &&
    grep -Fxq 'ENV BUNDLE_FROZEN=true' "${dockerfile}" &&
    grep -Fq 'python3' "${dockerfile}" &&
    grep -Eq 'image: postgres:17\.11@sha256:[0-9a-f]{64}' "${compose_file}" &&
    ! grep -Fxq '/Gemfile.lock' "${dockerignore}" &&
    ! grep -Fxq 'Gemfile.lock' "${gitignore}"
}

expect_success "canonical runner pins images and uses the committed lockfile" \
  verify_canonical_runner_contract

printf '\nRelease helper tests: %s passed, %s failed\n' "${pass}" "${fail}"
[[ "${fail}" -eq 0 ]]
