#!/usr/bin/env bash
set -Eeuo pipefail

AUTHORITATIVE_FOCUSED_REPETITIONS=50
AUTHORITATIVE_FULL_SUITE_REPETITIONS=10
AUTHORITATIVE_PARALLEL_WORKERS=4

FOCUSED_REPETITIONS="${FOCUSED_REPETITIONS-${AUTHORITATIVE_FOCUSED_REPETITIONS}}"
FULL_SUITE_REPETITIONS="${FULL_SUITE_REPETITIONS-${AUTHORITATIVE_FULL_SUITE_REPETITIONS}}"
PARALLEL_WORKERS="${PARALLEL_WORKERS-${AUTHORITATIVE_PARALLEL_WORKERS}}"

assert_canonical_count() {
  local name="$1" value="$2" expected="$3"
  if [[ ! "${value}" =~ ^[0-9]+$ ]]; then
    echo "FAIL ${name} must be a nonnegative integer, got '${value}'" >&2
    exit 2
  fi
  if (( value != expected )); then
    echo "FAIL ${name} must be exactly ${expected} for the authoritative release contract, got ${value}" >&2
    exit 2
  fi
}

assert_canonical_count FOCUSED_REPETITIONS "${FOCUSED_REPETITIONS}" "${AUTHORITATIVE_FOCUSED_REPETITIONS}"
assert_canonical_count FULL_SUITE_REPETITIONS "${FULL_SUITE_REPETITIONS}" "${AUTHORITATIVE_FULL_SUITE_REPETITIONS}"
assert_canonical_count PARALLEL_WORKERS "${PARALLEL_WORKERS}" "${AUTHORITATIVE_PARALLEL_WORKERS}"

if [[ "${STRESS_VALIDATE_ONLY-0}" == "1" ]]; then
  echo "PASS deterministic stress validation focused=${FOCUSED_REPETITIONS} full=${FULL_SUITE_REPETITIONS} workers=${PARALLEL_WORKERS}"
  exit 0
fi

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

rm -rf script/models/__pycache__

echo "PASS deterministic stress focused=${FOCUSED_REPETITIONS} full=${FULL_SUITE_REPETITIONS} workers=${PARALLEL_WORKERS}"
