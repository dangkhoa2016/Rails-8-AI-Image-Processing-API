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
    grep -Fq 'jq' "${dockerfile}" &&
    grep -Eq 'image: postgres:17\.11@sha256:[0-9a-f]{64}' "${compose_file}" &&
    ! grep -Fxq '/Gemfile.lock' "${dockerignore}" &&
    ! grep -Fxq 'Gemfile.lock' "${gitignore}"
}

expect_success "canonical runner pins images and uses the committed lockfile" \
  verify_canonical_runner_contract

REQUIRED_RUNNER_PACKAGES=(build-essential curl git jq libpq-dev pkg-config python3 unzip libvips)

gate_image_reference() {
  local compose_file="$1"
  awk '/^[[:space:]]+gate:/{in_gate=1} in_gate && /^[[:space:]]+image:/{print; exit}' "${compose_file}"
}

assert_runner_immutable_authority() {
  local dockerfile="$1"
  local compose_file="$2"
  local gate_ref
  local pkg
  local pinned=0
  local missing=0

  gate_ref="$(gate_image_reference "${compose_file}")"
  if [[ -n "${gate_ref}" ]]; then
    # The authoritative gate must consume a prebuilt runner image by exact
    # immutable digest; a mutable tag or untagged reference is floating.
    grep -Eq '@sha256:[0-9a-f]{64}' <<<"${gate_ref}" || return 1
    return 0
  fi

  # Otherwise the gate builds the runner, so the build must be immutable:
  # a fixed Debian snapshot source with every required package version-pinned.
  grep -Eq 'snapshot\.debian\.org/archive/[a-z]+/[0-9]{8}T[0-9]{6}Z/' "${dockerfile}" || return 1
  grep -Eq 'deb\.debian\.org' "${dockerfile}" && return 1
  grep -Eq 'apt-get update' "${dockerfile}" || return 1

  for pkg in "${REQUIRED_RUNNER_PACKAGES[@]}"; do
    if [[ "${pkg}" == libvips ]]; then
      grep -Eq '^[[:space:]]*libvips[0-9]+[a-z0-9.\-]*=[0-9][^[:space:]]*' "${dockerfile}" || missing=1
    else
      grep -Eq "^[[:space:]]*${pkg}=[0-9][^[:space:]]*" "${dockerfile}" || missing=1
    fi
  done
  [[ "${missing}" -eq 0 ]] || return 1

  # No required package may be installed without an exact version pin.
  for pkg in "${REQUIRED_RUNNER_PACKAGES[@]}"; do
    if grep -Eq "([[:space:]]|^)${pkg}([[:space:]#\\]|$)" "${dockerfile}"; then
      pinned=1
    fi
  done
  [[ "${pinned}" -eq 0 ]]
}

verify_runner_system_packages_immutable() {
  local dockerfile="${SCRIPT_DIR}/../../docker/release-gate/Dockerfile"
  local compose_file="${SCRIPT_DIR}/../../docker/release-gate/compose.yml"
  assert_runner_immutable_authority "${dockerfile}" "${compose_file}"
}

verify_floating_apt_runner_rejected() {
  local fixture dockerfile compose_file rc
  fixture="$(mktemp -d)"
  trap 'rm -rf "${fixture}"' RETURN
  dockerfile="${fixture}/Dockerfile"
  compose_file="${fixture}/compose.yml"

  cat > "${dockerfile}" <<'F'
FROM ruby:3.3.12-slim@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      curl \
      git
F
  cat > "${compose_file}" <<'F'
services:
  gate:
    build:
      context: ../..
      dockerfile: Dockerfile
F

  set +e
  assert_runner_immutable_authority "${dockerfile}" "${compose_file}"
  rc=$?
  set -e
  rm -rf "${fixture}"
  trap - RETURN
  [[ "${rc}" -ne 0 ]]
}

verify_unversioned_required_package_rejected() {
  local fixture dockerfile compose_file rc
  fixture="$(mktemp -d)"
  trap 'rm -rf "${fixture}"' RETURN
  dockerfile="${fixture}/Dockerfile"
  compose_file="${fixture}/compose.yml"

  cat > "${dockerfile}" <<'F'
FROM ruby:3.3.12-slim@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
RUN printf 'deb [check-valid-until=no] https://snapshot.debian.org/archive/debian/20260915T000000Z/ trixie main\n' > /etc/apt/sources.list.d/snapshot.list && \
    rm -f /etc/apt/sources.list /etc/apt/sources.list.d/debian.sources && \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      curl=8.14.1-2+deb13u5
F
  cat > "${compose_file}" <<'F'
services:
  gate:
    build:
      context: ../..
      dockerfile: Dockerfile
F

  set +e
  assert_runner_immutable_authority "${dockerfile}" "${compose_file}"
  rc=$?
  set -e
  rm -rf "${fixture}"
  trap - RETURN
  [[ "${rc}" -ne 0 ]]
}

verify_unpinned_runner_image_rejected() {
  local fixture compose_file rc
  fixture="$(mktemp -d)"
  trap 'rm -rf "${fixture}"' RETURN
  compose_file="${fixture}/compose.yml"

  cat > "${compose_file}" <<'F'
services:
  gate:
    image: ghcr.io/example/release-runner:latest
    command: ["bash"]
F

  set +e
  assert_runner_immutable_authority /dev/null "${compose_file}"
  rc=$?
  set -e
  rm -rf "${fixture}"
  trap - RETURN
  [[ "${rc}" -ne 0 ]]
}

verify_digest_pinned_runner_image_accepted() {
  local fixture compose_file rc
  fixture="$(mktemp -d)"
  trap 'rm -rf "${fixture}"' RETURN
  compose_file="${fixture}/compose.yml"

  cat > "${compose_file}" <<'F'
services:
  gate:
    image: ghcr.io/example/release-runner@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
    command: ["bash"]
F

  set +e
  assert_runner_immutable_authority /dev/null "${compose_file}"
  rc=$?
  set -e
  rm -rf "${fixture}"
  trap - RETURN
  [[ "${rc}" -eq 0 ]]
}

expect_success "canonical runner resolves system packages from an immutable authority" \
  verify_runner_system_packages_immutable

expect_success "floating apt repository runner definition is rejected" \
  verify_floating_apt_runner_rejected

expect_success "unversioned required package install is rejected" \
  verify_unversioned_required_package_rejected

expect_success "non-digest runner image reference is rejected" \
  verify_unpinned_runner_image_rejected

expect_success "digest-pinned runner image reference is accepted" \
  verify_digest_pinned_runner_image_accepted

verify_deterministic_gate_contract() {
  local gate="${SCRIPT_DIR}/verify_deterministic_gate.sh"
  [[ -x "${gate}" ]] &&
    grep -Fq 'canonical release gate requires exactly one incremental base' "${gate}" &&
    grep -Fq "assert_clean 'requires a clean worktree before validation'" "${gate}" &&
    grep -Fq "assert_clean 'left worktree dirty'" "${gate}" &&
    grep -Fq 'PARALLEL_WORKERS=4' "${gate}"
}

expect_success "canonical deterministic gate requires clean state and parallel workers" \
  verify_deterministic_gate_contract

verify_archive_hygiene_contract() {
  local helper="${SCRIPT_DIR}/verify_source_archive_hygiene.sh" fixture
  fixture="$(mktemp -d)"
  trap 'rm -rf "${fixture}"' RETURN
  python3 - "${fixture}/forbidden.zip" "${fixture}/clean.zip" <<'PY'
import sys
from zipfile import ZipFile
with ZipFile(sys.argv[1], "w") as archive:
    archive.writestr("project/docs/superpowers/plan.md", "forbidden")
with ZipFile(sys.argv[2], "w") as archive:
    archive.writestr("project/README.md", "clean")
PY
  local result=0
  "${helper}" "${fixture}/clean.zip" && ! "${helper}" "${fixture}/forbidden.zip" || result=1
  rm -rf "${fixture}"
  trap - RETURN
  return "${result}"
}

expect_success "archive hygiene rejects forbidden source paths" verify_archive_hygiene_contract

verify_stress_contract() {
  local stress="${SCRIPT_DIR}/stress_deterministic_gate.sh"
  [[ -x "${stress}" ]] &&
    grep -Fq 'AUTHORITATIVE_FOCUSED_REPETITIONS=50' "${stress}" &&
    grep -Fq 'AUTHORITATIVE_FULL_SUITE_REPETITIONS=10' "${stress}" &&
    grep -Fq 'AUTHORITATIVE_PARALLEL_WORKERS=4' "${stress}" &&
    grep -Fq 'assert_canonical_count' "${stress}" &&
    grep -Fq 'find tmp/image_lab -type f -print' "${stress}"
}

expect_success "deterministic stress protocol requires exact 50/10/4 canonical counts" verify_stress_contract

verify_authoritative_stress_admission() {
  local focused="$1" full="$2" workers="$3" expected="$4"
  local fixture fake_bin invocation_log output rc invocation_count
  fixture="$(mktemp -d)"
  trap 'rm -rf "${fixture}"' RETURN
  fake_bin="${fixture}/fake-bin"
  invocation_log="${fixture}/invocations.log"

  copy_repository_fixture "${fixture}"
  mkdir -p "${fake_bin}"
  : > "${invocation_log}"
  cat > "${fake_bin}/ruby" <<'SH'
#!/usr/bin/env bash
printf 'ruby %s\n' "$*" >> "${STRESS_INVOCATION_LOG}"
exit 97
SH
  cat > "${fake_bin}/bundle" <<'SH'
#!/usr/bin/env bash
printf 'bundle %s\n' "$*" >> "${STRESS_INVOCATION_LOG}"
exit 97
SH
  chmod +x "${fake_bin}/ruby" "${fake_bin}/bundle"

  set +e
  output="$(cd "${fixture}/repository" && PATH="${fake_bin}:${PATH}" STRESS_INVOCATION_LOG="${invocation_log}" STRESS_VALIDATE_ONLY=1 FOCUSED_REPETITIONS="${focused}" FULL_SUITE_REPETITIONS="${full}" PARALLEL_WORKERS="${workers}" bash scripts/release/stress_deterministic_gate.sh 2>&1)"
  rc=$?
  set -e
  invocation_count="$(wc -l < "${invocation_log}" 2>/dev/null || true)"

  rm -rf "${fixture}"
  trap - RETURN

  if [[ "${expected}" == reject ]]; then
    [[ "${rc}" -ne 0 ]] &&
      [[ "${invocation_count}" -eq 0 ]] &&
      ! grep -Fq 'PASS deterministic stress' <<<"${output}"
  else
    [[ "${rc}" -eq 0 ]] &&
      [[ "${invocation_count}" -eq 0 ]]
  fi
}

expect_success "authoritative stress rejects zero focused repetitions" \
  verify_authoritative_stress_admission 0 10 4 reject
expect_success "authoritative stress rejects zero full-suite repetitions" \
  verify_authoritative_stress_admission 50 0 4 reject
expect_success "authoritative stress rejects negative focused repetitions" \
  verify_authoritative_stress_admission -1 10 4 reject
expect_success "authoritative stress rejects negative full-suite repetitions" \
  verify_authoritative_stress_admission 50 -1 4 reject
expect_success "authoritative stress rejects nonnumeric focused repetitions" \
  verify_authoritative_stress_admission abc 10 4 reject
expect_success "authoritative stress rejects nonnumeric full-suite repetitions" \
  verify_authoritative_stress_admission 50 abc 4 reject
expect_success "authoritative stress rejects noncanonical focused repetitions" \
  verify_authoritative_stress_admission 49 10 4 reject
expect_success "authoritative stress rejects noncanonical full-suite repetitions" \
  verify_authoritative_stress_admission 50 9 4 reject
expect_success "authoritative stress rejects fewer than four workers" \
  verify_authoritative_stress_admission 50 10 1 reject
expect_success "authoritative stress rejects noncanonical worker counts" \
  verify_authoritative_stress_admission 50 10 3 reject
expect_success "authoritative stress admits canonical counts without workloads" \
  verify_authoritative_stress_admission 50 10 4 accept

verify_stress_executes_each_requested_iteration() {
  local fixture fake_bin invocation_log output rc ruby_invocations bundle_invocations prepare_invocations cleanup_removed
  fixture="$(mktemp -d)"
  trap 'rm -rf "${fixture}"' RETURN
  fake_bin="${fixture}/fake-bin"
  invocation_log="${fixture}/invocations.log"

  copy_repository_fixture "${fixture}"
  mkdir -p "${fixture}/repository/tmp/image_lab" "${fake_bin}"
  cat > "${fake_bin}/ruby" <<'SH'
#!/usr/bin/env bash
printf 'ruby %s\n' "$*" >> "${STRESS_INVOCATION_LOG}"
mkdir -p script/models/__pycache__
touch script/models/__pycache__/stress-test.pyc
SH
  cat > "${fake_bin}/bundle" <<'SH'
#!/usr/bin/env bash
printf 'bundle %s\n' "$*" >> "${STRESS_INVOCATION_LOG}"
SH
  chmod +x "${fake_bin}/ruby" "${fake_bin}/bundle"

  set +e
  output="$(cd "${fixture}/repository" && PATH="${fake_bin}:${PATH}" STRESS_INVOCATION_LOG="${invocation_log}" FOCUSED_REPETITIONS=50 FULL_SUITE_REPETITIONS=10 PARALLEL_WORKERS=4 bash scripts/release/stress_deterministic_gate.sh 2>&1)"
  rc=$?
  set -e
  ruby_invocations="$(grep -c '^ruby script/benchmark_vips_cpu_8gb.rb --quick --workers 4$' "${invocation_log}" 2>/dev/null || true)"
  bundle_invocations="$(grep -c '^bundle exec rails test$' "${invocation_log}" 2>/dev/null || true)"
  prepare_invocations="$(grep -c '^bundle exec rails db:prepare$' "${invocation_log}" 2>/dev/null || true)"
  [[ ! -e "${fixture}/repository/script/models/__pycache__" ]] && cleanup_removed=yes || cleanup_removed=no

  rm -rf "${fixture}"
  trap - RETURN

  [[ "${rc}" -eq 0 ]] &&
    [[ "${ruby_invocations}" -eq 50 ]] &&
    [[ "${bundle_invocations}" -eq 10 ]] &&
    [[ "${prepare_invocations}" -eq 1 ]] &&
    [[ "${cleanup_removed}" == yes ]] &&
    grep -Fxq 'PASS deterministic stress focused=50 full=10 workers=4' <<<"${output}"
}

expect_success "deterministic stress executes every requested iteration" verify_stress_executes_each_requested_iteration

printf '\nRelease helper tests: %s passed, %s failed\n' "${pass}" "${fail}"
[[ "${fail}" -eq 0 ]]
