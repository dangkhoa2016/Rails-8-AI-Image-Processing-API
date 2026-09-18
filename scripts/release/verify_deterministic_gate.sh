#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "$#" -ne 1 ]]; then
  echo 'FAIL canonical release gate requires exactly one incremental base' >&2
  exit 2
fi

base="$1"
git cat-file -e "${base}^{commit}"

assert_clean() {
  local phase="$1" status
  status="$(git status --porcelain=v1)"
  [[ -z "${status}" ]] || {
    echo "FAIL canonical release gate ${phase} worktree dirty" >&2
    printf '%s\n' "${status}" >&2
    exit 1
  }
}

assert_clean 'requires a clean worktree before validation'
for executable in git python3 ruby; do
  command -v "${executable}" >/dev/null || { echo "FAIL missing ${executable}" >&2; exit 1; }
done

PARALLEL_WORKERS=4 bundle exec rails test
bin/rubocop
bin/brakeman --no-pager
bash scripts/release/test_release_tools.sh
bash scripts/release/verify_repository.sh
ruby bin/check_repository_policy HEAD "${base}"
rm -rf deploy/beam/__pycache__ script/models/__pycache__
git diff --check "${base}..HEAD"
assert_clean 'left worktree dirty'
printf 'PASS canonical deterministic gate HEAD=%s PARALLEL_WORKERS=4\n' "$(git rev-parse HEAD)"
