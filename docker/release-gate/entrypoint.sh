#!/usr/bin/env bash
set -Eeuo pipefail

cd /workspace
git config --global --add safe.directory /workspace
bundle check
exec "$@"
