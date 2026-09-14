#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_SCRIPT="$SCRIPT_DIR/app.py"
DEPLOY_SCRIPT="$SCRIPT_DIR/deploy.sh"

pass=0
fail=0
ok() { printf 'PASS %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL %s\n' "$1" >&2; fail=$((fail + 1)); }

python3 - "$APP_SCRIPT" <<'PY'
import importlib.util
import pathlib
import sys
import types

app_path = pathlib.Path(sys.argv[1])
records = {}

class FakeImage:
    @classmethod
    def from_dockerfile(cls, path, **kwargs):
        records["dockerfile"] = (str(path), kwargs)
        return cls()
    def entrypoint(self, commands):
        records["entrypoint"] = commands
        return self

class FakeSecret:
    @classmethod
    def from_name(cls, name, **kwargs):
        records["secret"] = (name, kwargs)
        return ("secret", name)

class FakeVolumeHandle:
    def with_mount_options(self, **kwargs):
        records["mount_options"] = kwargs
        return ("volume", kwargs)

class FakeVolume:
    @classmethod
    def from_name(cls, name, **kwargs):
        records["volume"] = (name, kwargs)
        return FakeVolumeHandle()

class FakeApp:
    def __init__(self, name):
        records["app_name"] = name
    def function(self, **kwargs):
        records["function"] = kwargs
        return lambda fn: fn

def web_server(port, **kwargs):
    records["web_server"] = (port, kwargs)
    return lambda fn: fn

fake = types.ModuleType("modal")
fake.Image = FakeImage
fake.Secret = FakeSecret
fake.Volume = FakeVolume
fake.App = FakeApp
fake.web_server = web_server
fake.is_local = lambda: True
sys.modules["modal"] = fake

spec = importlib.util.spec_from_file_location("modal_app_under_test", app_path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

assert records["app_name"] == "rails-8-ai-image-processing-api"
assert records["dockerfile"][1]["add_python"] == "3.12"
assert pathlib.Path(records["dockerfile"][0]) == app_path.parents[2] / "Dockerfile"
assert pathlib.Path(records["dockerfile"][1]["context_dir"]) == app_path.parents[2]
assert records["entrypoint"] == []

name, secret = records["secret"]
assert name == "rails-api-production"
required = set(secret["required_keys"])
for key in {
    "RAILS_MASTER_KEY", "DATABASE_URL", "CACHE_DATABASE_URL", "QUEUE_DATABASE_URL",
    "CABLE_DATABASE_URL", "CORS_ALLOWED_ORIGINS", "SMTP_ADDRESS", "SMTP_PORT",
    "SMTP_USERNAME", "SMTP_PASSWORD", "DEVISE_MAILER_SENDER", "APP_HOST",
    "APP_PROTOCOL", "PUBLIC_DEMO_EMAIL_GUARD",
}:
    assert key in required

volume_name, volume_args = records["volume"]
assert volume_name == "rails-8-ai-image-processing-models"
assert volume_args == {"create_if_missing": False}
assert records["mount_options"] == {"read_only": True}

fn = records["function"]
assert fn["cpu"] == 2.0
assert fn["memory"] == 10240
assert fn["min_containers"] == 0
assert fn["max_containers"] == 1
assert fn["buffer_containers"] == 0
assert fn["scaledown_window"] == 60
assert fn["volumes"] == {"/rails/var/models": ("volume", {"read_only": True})}
assert fn["env"]["RAILS_ENV"] == "production"
assert fn["env"]["WEB_CONCURRENCY"] == "1"
assert fn["env"]["RAILS_MAX_THREADS"] == "3"
assert fn["env"]["IMAGE_AI_MAX_CONCURRENCY"] == "1"
assert records["web_server"] == (4000, {"startup_timeout": 120, "requires_proxy_auth": False})
PY
ok 'app.py enforces qualified AI production envelope and read-only model volume'

make_fixture() {
  local root="$1"
  mkdir -p "$root/deploy/modal" "$root/fakebin" "$root/config/credentials"
  cp "$APP_SCRIPT" "$root/deploy/modal/app.py"
  cp "$DEPLOY_SCRIPT" "$root/deploy/modal/deploy.sh"
  printf 'encrypted-production-fixture\n' > "$root/config/credentials/production.yml.enc"
  chmod +x "$root/deploy/modal/deploy.sh"

  cat > "$root/fakebin/modal" <<'MODAL'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >> "$FAKE_MODAL_LOG"
if [[ "$1 $2" == "secret list" ]]; then
  cat "$FAKE_SECRET_JSON"
  exit 0
fi
if [[ "$1 $2" == "volume list" ]]; then
  cat "$FAKE_VOLUME_JSON"
  exit 0
fi
if [[ "$1" == "deploy" ]]; then
  printf 'Deployed\n'
  exit 0
fi
exit 64
MODAL
  chmod +x "$root/fakebin/modal"

  git -C "$root" init -q -b main
  git -C "$root" config user.email test@example.invalid
  git -C "$root" config user.name Test
  git -C "$root" add deploy config/credentials/production.yml.enc
  git -C "$root" commit -qm fixture
  git -C "$root" tag -a v1.0.0 -m v1.0.0
  git -C "$root" remote add origin .
}

run_case() {
  local mode="$1"
  local root secrets volumes log output
  root="$(mktemp -d)"
  secrets="$(mktemp)"
  volumes="$(mktemp)"
  log="$(mktemp)"
  output="$(mktemp)"
  make_fixture "$root"

  printf '[{"name":"rails-api-production"}]\n' > "$secrets"
  printf '[{"name":"rails-8-ai-image-processing-models"}]\n' > "$volumes"

  case "$mode" in
    dirty_tracked)
      printf '# dirty\n' >> "$root/deploy/modal/app.py"
      ;;
    dirty_untracked)
      printf 'untracked\n' > "$root/UNTRACKED_DEPLOY_NOTE.txt"
      ;;
    wrong_branch)
      git -C "$root" checkout -qb feature
      ;;
    head_not_main)
      git -C "$root" checkout -qb local-ahead
      printf 'ahead\n' > "$root/ahead.txt"
      git -C "$root" add ahead.txt
      git -C "$root" commit -qm ahead
      git -C "$root" checkout -q main
      git -C "$root" reset --hard local-ahead >/dev/null
      ;;
    tag_mismatch)
      git -C "$root" tag -d v1.0.0 >/dev/null
      first="$(git -C "$root" rev-list --max-parents=0 HEAD)"
      git -C "$root" tag -a v1.0.0 "$first" -m v1.0.0
      ;;
    missing_secret)
      printf '[{"name":"other"}]\n' > "$secrets"
      ;;
    missing_volume)
      printf '[{"name":"other"}]\n' > "$volumes"
      ;;
    tracked_key)
      printf 'do-not-commit\n' > "$root/config/credentials/production.key"
      git -C "$root" add config/credentials/production.key
      git -C "$root" commit -qm 'track forbidden key fixture'
      git -C "$root" tag -f -a v1.0.0 -m v1.0.0 >/dev/null
      ;;
  esac

  local rc=0
  set +e
  PATH="$root/fakebin:$PATH" FAKE_MODAL_LOG="$log" FAKE_SECRET_JSON="$secrets" FAKE_VOLUME_JSON="$volumes"     "$root/deploy/modal/deploy.sh" > "$output" 2>&1
  rc=$?
  set -e

  case "$mode" in
    success)
      [[ $rc -eq 0 ]] &&
        grep -Fq 'secret list --json' "$log" &&
        grep -Fq 'volume list --json' "$log" &&
        grep -Fq 'deploy deploy/modal/app.py --name rails-8-ai-image-processing-api' "$log"
      ;;
    dirty_tracked|dirty_untracked)
      [[ $rc -ne 0 ]] && grep -Fq 'production deploy requires an entirely clean worktree' "$output"
      ;;
    wrong_branch)
      [[ $rc -ne 0 ]] && grep -Fq 'production deploy requires branch main' "$output"
      ;;
    head_not_main)
      [[ $rc -ne 0 ]] && grep -Fq 'HEAD does not match remote origin/main' "$output"
      ;;
    tag_mismatch)
      [[ $rc -ne 0 ]] && grep -Fq 'HEAD does not match peeled remote v1.0.0 target' "$output"
      ;;
    missing_secret)
      [[ $rc -ne 0 ]] && grep -Fq 'missing required Modal secret: rails-api-production' "$output"
      ;;
    missing_volume)
      [[ $rc -ne 0 ]] && grep -Fq 'missing required Modal volume: rails-8-ai-image-processing-models' "$output"
      ;;
    tracked_key)
      [[ $rc -ne 0 ]] && grep -Fq 'production credentials key must never be committed' "$output"
      ;;
  esac

  rm -rf "$root" "$secrets" "$volumes" "$log" "$output"
}

for mode in success dirty_tracked dirty_untracked wrong_branch head_not_main tag_mismatch missing_secret missing_volume tracked_key; do
  if run_case "$mode"; then ok "deploy preflight: $mode"; else bad "deploy preflight: $mode"; fi
done

if "$DEPLOY_SCRIPT" --unknown >/dev/null 2>&1; then
  bad 'rejects unknown CLI arguments'
else
  ok 'rejects unknown CLI arguments'
fi

printf '\nModal deploy tests: %s passed, %s failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
