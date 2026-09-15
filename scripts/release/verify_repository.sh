#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo 'FAIL repository release verification requires a valid Git worktree' >&2
  exit 1
fi

required=(
  CHANGELOG.md
  docs/RELEASE_PROCESS.md
  docs/RELEASE_PROCESS.vi.md
  docs/releases/v1.0.0-acceptance.md
  deploy/beam/Dockerfile
  deploy/beam/app.py
  deploy/beam/entrypoint.sh
  deploy/beam/deploy.sh
  deploy/beam/test_deploy.sh
  deploy/beam/README.md
  deploy/beam/README.vi.md
  deploy/huggingface/Dockerfile
  deploy/huggingface/README.md
  deploy/huggingface/README.vi.md
  scripts/release/lib.sh
  scripts/release/test_refresh_v1_0_0_tag.sh
  scripts/release/test_release_tools.sh
  scripts/release/verify_ghcr.sh
  scripts/release/smoke_deployment.sh
  script/refresh_v1_0_0_tag.sh
)

for path in "${required[@]}"; do
  [[ -s "${path}" ]] || { echo "FAIL missing/empty ${path}" >&2; exit 1; }
done

grep -Eq '^  push:$' .github/workflows/ci.yml
grep -Eq '^    branches: \[main\]$|^      - main$' .github/workflows/ci.yml

if grep -REn 'T[B]D|T[O]DO|implement later|fill in details' \
  CHANGELOG.md docs/RELEASE_PROCESS.md docs/RELEASE_PROCESS.vi.md deploy; then
  echo 'FAIL unresolved release marker found' >&2
  exit 1
fi

tracked_deploy_files="$(git ls-files -- deploy)" || {
  echo 'FAIL unable to enumerate tracked deploy files' >&2
  exit 1
}

if grep -Eq '(^|/)(production\.key|master\.key)$|(^|/)credentials/.*\.key$' <<<"${tracked_deploy_files}"; then
  echo 'FAIL tracked private key path under deploy/' >&2
  exit 1
fi

if grep -REn '(postgres(ql)?://[^[:space:]]+:[^[:space:]@]+@|RAILS_MASTER_KEY=.+|SECRET_KEY_BASE=.{16,}|DEVISE_JWT_SECRET_KEY=.{16,})' deploy; then
  echo 'FAIL likely committed secret value under deploy/' >&2
  exit 1
fi

bash -n scripts/release/lib.sh
bash -n script/refresh_v1_0_0_tag.sh
bash -n scripts/release/test_refresh_v1_0_0_tag.sh
bash -n scripts/release/test_release_tools.sh
bash -n scripts/release/verify_ghcr.sh
bash -n scripts/release/smoke_deployment.sh
bash -n deploy/beam/entrypoint.sh
bash -n deploy/beam/deploy.sh
bash -n deploy/beam/test_deploy.sh
ruby -c deploy/beam/beam_logging.rb >/dev/null
python -m py_compile deploy/beam/app.py
bash deploy/beam/test_deploy.sh

echo 'PASS repository release contract'
