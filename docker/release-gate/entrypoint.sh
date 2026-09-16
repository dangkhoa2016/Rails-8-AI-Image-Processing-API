#!/usr/bin/env bash
set -Eeuo pipefail

cd /workspace
bundle check
exec "$@"
