#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="rails-8-ai-image-processing-api"
SECRET_NAME="rails-api-production"
MODEL_VOLUME_NAME="rails-8-ai-image-processing-models"
PRODUCTION_CREDENTIALS="config/credentials/production.yml.enc"
PRODUCTION_KEY="config/credentials/production.key"
RELEASE_TAG="v1.0.0"
MODAL_ENV=""
SMOKE_URL=""

info() { printf '[INFO] %s\n' "$*"; }
pass() { printf '[PASS] %s\n' "$*"; }
die() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
Usage: deploy/modal/deploy.sh [--env NAME] [--smoke URL]

Deploy the public Modal Rails AI demo from deploy/modal/app.py.

Production invariants:
  - the entire Git worktree, including untracked files, must be clean;
  - the current branch must be main;
  - HEAD must exactly match remote origin/main;
  - HEAD must exactly match the peeled remote v1.0.0 tag target;
  - production credentials must be committed, but production.key must not be;
  - the rails-api-production secret and rails-8-ai-image-processing-models volume must already exist.

Options:
  --env NAME    Use a specific Modal environment.
  --smoke URL   Run deploy/modal/smoke.sh against URL after deploy.
  -h, --help    Show this help.

This script never creates, prints, or persists production secret values or model artifacts.
USAGE
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is required"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      [[ $# -ge 2 && -n "${2:-}" ]] || die '--env requires a value'
      MODAL_ENV="$2"
      shift 2
      ;;
    --smoke)
      [[ $# -ge 2 && -n "${2:-}" ]] || die '--smoke requires a value'
      SMOKE_URL="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

require_command git
require_command python3
require_command modal

REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)" || die 'deploy script must run from a Git repository checkout'
[[ "$SCRIPT_DIR" == "$REPO_ROOT/deploy/modal" ]] || die 'expected script at deploy/modal/deploy.sh inside the repository'
[[ -f "$SCRIPT_DIR/app.py" ]] || die 'missing Modal deployment file: deploy/modal/app.py'

[[ -s "$REPO_ROOT/$PRODUCTION_CREDENTIALS" ]] || die "missing/empty production credentials: $PRODUCTION_CREDENTIALS"
git -C "$REPO_ROOT" ls-files --error-unmatch "$PRODUCTION_CREDENTIALS" >/dev/null 2>&1 ||   die "production credentials must be committed before deployment: $PRODUCTION_CREDENTIALS"

if git -C "$REPO_ROOT" ls-files --error-unmatch "$PRODUCTION_KEY" >/dev/null 2>&1; then
  die "production credentials key must never be committed: $PRODUCTION_KEY"
fi

if [[ -n "$(git -C "$REPO_ROOT" status --porcelain --untracked-files=all)" ]]; then
  die 'repository has tracked or untracked changes; production deploy requires an entirely clean worktree'
fi

SOURCE_BRANCH="$(git -C "$REPO_ROOT" symbolic-ref --quiet --short HEAD 2>/dev/null || printf 'DETACHED')"
[[ "$SOURCE_BRANCH" == "main" ]] || die "production deploy requires branch main; current branch: $SOURCE_BRANCH"

SOURCE_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD)"
REMOTE_MAIN="$(git -C "$REPO_ROOT" ls-remote --exit-code origin refs/heads/main | awk 'NR==1 {print $1}')"
[[ -n "$REMOTE_MAIN" ]] || die 'cannot resolve remote origin/main'
[[ "$SOURCE_SHA" == "$REMOTE_MAIN" ]] || die "HEAD does not match remote origin/main: local=$SOURCE_SHA remote=$REMOTE_MAIN"

REMOTE_TAG_TARGET="$(git -C "$REPO_ROOT" ls-remote --exit-code origin "refs/tags/$RELEASE_TAG^{}" | awk 'NR==1 {print $1}')"
[[ -n "$REMOTE_TAG_TARGET" ]] || die "cannot resolve peeled remote release tag: $RELEASE_TAG"
[[ "$SOURCE_SHA" == "$REMOTE_TAG_TARGET" ]] ||   die "HEAD does not match peeled remote $RELEASE_TAG target: local=$SOURCE_SHA tag=$REMOTE_TAG_TARGET"

python3 -m py_compile "$SCRIPT_DIR/app.py"

if [[ -n "$SMOKE_URL" ]]; then
  [[ "$SMOKE_URL" =~ ^https?://[^[:space:]]+$ ]] || die '--smoke must be an http:// or https:// URL'
  while [[ "$SMOKE_URL" == */ ]]; do SMOKE_URL="${SMOKE_URL%/}"; done
  [[ -x "$SCRIPT_DIR/smoke.sh" ]] || die 'deploy/modal/smoke.sh is missing or not executable'
fi

env_args=()
if [[ -n "$MODAL_ENV" ]]; then
  env_args=(--env "$MODAL_ENV")
fi

secret_json="$(mktemp)"
volume_json="$(mktemp)"
trap 'rm -f "$secret_json" "$volume_json"' EXIT

modal secret list --json "${env_args[@]}" > "$secret_json" || die 'cannot list Modal secrets; verify Modal authentication/environment'
modal volume list --json "${env_args[@]}" > "$volume_json" || die 'cannot list Modal volumes; verify Modal authentication/environment'

python3 - "$secret_json" "$SECRET_NAME" <<'PY' || exit 1
import json, sys
path, required = sys.argv[1:3]
try:
    payload = json.load(open(path, encoding="utf-8"))
except (OSError, json.JSONDecodeError) as exc:
    print(f"[FAIL] cannot parse 'modal secret list --json': {exc}", file=sys.stderr)
    raise SystemExit(1)
items = payload if isinstance(payload, list) else payload.get("secrets", []) if isinstance(payload, dict) else []
if not any(isinstance(item, dict) and (item.get("name") or item.get("Name")) == required for item in items):
    print(f"[FAIL] missing required Modal secret: {required}", file=sys.stderr)
    raise SystemExit(1)
PY

python3 - "$volume_json" "$MODEL_VOLUME_NAME" <<'PY' || exit 1
import json, sys
path, required = sys.argv[1:3]
try:
    payload = json.load(open(path, encoding="utf-8"))
except (OSError, json.JSONDecodeError) as exc:
    print(f"[FAIL] cannot parse 'modal volume list --json': {exc}", file=sys.stderr)
    raise SystemExit(1)
items = payload if isinstance(payload, list) else payload.get("volumes", []) if isinstance(payload, dict) else []
if not any(isinstance(item, dict) and (item.get("name") or item.get("Name")) == required for item in items):
    print(f"[FAIL] missing required Modal volume: {required}", file=sys.stderr)
    raise SystemExit(1)
PY

info "repository branch: $SOURCE_BRANCH"
info "repository commit: $SOURCE_SHA"
info "release tag: $RELEASE_TAG"
info "Modal app: $APP_NAME"
info "Modal model volume: $MODEL_VOLUME_NAME"
info "Modal environment: ${MODAL_ENV:-current/default}"
pass 'Modal production preflight checks completed'

(
  cd "$REPO_ROOT"
  modal deploy deploy/modal/app.py --name "$APP_NAME" "${env_args[@]}"
)
pass 'Modal deploy command completed'

if [[ -n "$SMOKE_URL" ]]; then
  "$SCRIPT_DIR/smoke.sh" "$SMOKE_URL"
fi
