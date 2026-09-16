#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "$#" -ne 1 || ! -f "$1" ]]; then
  echo 'FAIL source archive hygiene requires one readable ZIP archive' >&2
  exit 2
fi

entries="$(unzip -Z1 "$1")"
if grep -Eq '(^|/)(\.git/|tmp/local_secret\.txt|log/(test|development)\.log|docs/superpowers/|var/models/u2netp\.(onnx|pth)|__pycache__/)' <<<"${entries}"; then
  echo 'FAIL source archive contains forbidden release paths' >&2
  grep -E '(^|/)(\.git/|tmp/local_secret\.txt|log/(test|development)\.log|docs/superpowers/|var/models/u2netp\.(onnx|pth)|__pycache__/)' <<<"${entries}" >&2
  exit 1
fi

printf 'PASS source archive hygiene entries=%s\n' "$(wc -l <<<"${entries}")"
