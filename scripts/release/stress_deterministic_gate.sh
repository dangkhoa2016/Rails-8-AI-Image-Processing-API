#!/usr/bin/env bash
set -Eeuo pipefail

FOCUSED_REPETITIONS="${FOCUSED_REPETITIONS:-50}"
FULL_SUITE_REPETITIONS="${FULL_SUITE_REPETITIONS:-10}"
PARALLEL_WORKERS="${PARALLEL_WORKERS:-4}"

[[ "${PARALLEL_WORKERS}" =~ ^[0-9]+$ ]] && (( PARALLEL_WORKERS >= 2 )) || {
  echo 'FAIL PARALLEL_WORKERS must be at least 2' >&2
  exit 2
}

RAILS_ENV=test bundle exec rails db:prepare

for ((index = 1; index <= FOCUSED_REPETITIONS; index++)); do
  seed=$((10000 + index))
  echo "FOCUSED_$(printf '%02d' "${index}") seed=${seed}"
  SEED="${seed}" ruby script/benchmark_vips_cpu_8gb.rb --quick --workers "${PARALLEL_WORKERS}"
done

for ((index = 1; index <= FULL_SUITE_REPETITIONS; index++)); do
  seed=$((31000 + index))
  echo "FULL_$(printf '%02d' "${index}") seed=${seed} workers=${PARALLEL_WORKERS}"
  PARALLEL_WORKERS="${PARALLEL_WORKERS}" SEED="${seed}" bundle exec rails test
  residue="$(find tmp/image_lab -type f -print)"
  [[ -z "${residue}" ]] || { echo 'FAIL scratch residue files remain' >&2; printf '%s\n' "${residue}" >&2; exit 1; }
done

echo "PASS deterministic stress focused=${FOCUSED_REPETITIONS} full=${FULL_SUITE_REPETITIONS} workers=${PARALLEL_WORKERS}"
