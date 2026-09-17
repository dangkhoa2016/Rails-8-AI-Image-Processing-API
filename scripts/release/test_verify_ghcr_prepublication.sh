#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/scripts/release/verify_ghcr.sh"

output_file="$(mktemp)"
trap 'rm -f "$output_file"' EXIT

set +e
bash "$SCRIPT" >"$output_file" 2>&1
status=$?
set -e

if [[ "$status" -ne 1 ]]; then
  printf 'FAIL expected pre-publication GHCR verifier to exit 1, got %s\n' "$status" >&2
  exit 1
fi

grep -Fq \
  'BLOCKED: Rails 8 AI Image Processing API has no published Docker image yet.' \
  "$output_file"

grep -Fq \
  'GHCR artifact verification will be defined with the first project release.' \
  "$output_file"

printf '%s\n' 'PASS pre-publication GHCR verification contract'
