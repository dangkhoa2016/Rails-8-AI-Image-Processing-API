#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/release/verify_ghcr.sh multi IMAGE TAG EXPECTED_REVISION EXPECTED_VERSION EXPECTED_AMD64_DIGEST EXPECTED_ARM64_DIGEST
  scripts/release/verify_ghcr.sh platform IMAGE TAG EXPECTED_REVISION EXPECTED_VERSION EXPECTED_OS EXPECTED_ARCH EXPECTED_CHILD_DIGEST
EOF
  exit 64
}

MODE="${1:-}"
[[ -n "${MODE}" ]] || usage
shift

command -v docker >/dev/null 2>&1 || {
  echo "ERROR: docker is required." >&2
  exit 69
}
command -v jq >/dev/null 2>&1 || {
  echo "ERROR: jq is required." >&2
  exit 69
}

inspect_raw_with_retry() {
  local ref="$1"
  local output=""
  local attempt

  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if output="$(docker buildx imagetools inspect "${ref}" --raw 2>/tmp/verify-ghcr.err)"; then
      printf '%s' "${output}"
      return 0
    fi

    echo "Waiting for registry consistency: ${ref} (${attempt}/10)" >&2
    sleep 3
  done

  echo "ERROR: unable to inspect ${ref}." >&2
  [[ ! -s /tmp/verify-ghcr.err ]] || cat /tmp/verify-ghcr.err >&2
  return 1
}

verify_common_annotations() {
  local json="$1"
  local revision="$2"
  local version="$3"

  jq -e     --arg revision "${revision}"     --arg version "${version}"     '
      ((.annotations // {})["org.opencontainers.image.revision"] == $revision)
      and ((.annotations // {})["org.opencontainers.image.version"] == $version)
      and (((.annotations // {})["org.opencontainers.image.title"] // "") | length > 0)
      and (((.annotations // {})["org.opencontainers.image.description"] // "") | length > 0)
    ' <<<"${json}" >/dev/null
}

case "${MODE}" in
  multi)
    [[ "$#" -eq 6 ]] || usage
    IMAGE="$1"
    TAG="$2"
    EXPECTED_REVISION="$3"
    EXPECTED_VERSION="$4"
    EXPECTED_AMD64_DIGEST="$5"
    EXPECTED_ARM64_DIGEST="$6"
    REF="${IMAGE}:${TAG}"
    JSON="$(inspect_raw_with_retry "${REF}")"

    verify_common_annotations "${JSON}" "${EXPECTED_REVISION}" "${EXPECTED_VERSION}"

    jq -e       --arg amd64 "${EXPECTED_AMD64_DIGEST}"       --arg arm64 "${EXPECTED_ARM64_DIGEST}"       '
        (
          .mediaType == "application/vnd.oci.image.index.v1+json"
          or .mediaType == "application/vnd.docker.distribution.manifest.list.v2+json"
        )
        and (
          [(.manifests // [])[]
           | select(.platform.os == "linux"
                    and .platform.architecture == "amd64"
                    and .digest == $amd64)]
          | length
        ) == 1
        and (
          [(.manifests // [])[]
           | select(.platform.os == "linux"
                    and .platform.architecture == "arm64"
                    and .digest == $arm64)]
          | length
        ) == 1
      ' <<<"${JSON}" >/dev/null

    printf 'GHCR_MULTI_VERIFY=PASS\n'
    printf 'REF=%s\n' "${REF}"
    printf 'LINUX_AMD64=%s\n' "${EXPECTED_AMD64_DIGEST}"
    printf 'LINUX_ARM64=%s\n' "${EXPECTED_ARM64_DIGEST}"
    ;;

  platform)
    [[ "$#" -eq 7 ]] || usage
    IMAGE="$1"
    TAG="$2"
    EXPECTED_REVISION="$3"
    EXPECTED_VERSION="$4"
    EXPECTED_OS="$5"
    EXPECTED_ARCH="$6"
    EXPECTED_CHILD_DIGEST="$7"
    REF="${IMAGE}:${TAG}"
    JSON="$(inspect_raw_with_retry "${REF}")"

    verify_common_annotations "${JSON}" "${EXPECTED_REVISION}" "${EXPECTED_VERSION}"

    jq -e       --arg os "${EXPECTED_OS}"       --arg arch "${EXPECTED_ARCH}"       --arg digest "${EXPECTED_CHILD_DIGEST}"       '
        (
          .mediaType == "application/vnd.oci.image.index.v1+json"
          or .mediaType == "application/vnd.docker.distribution.manifest.list.v2+json"
        )
        and (
          [(.manifests // [])[]
           | select(.platform.os == $os
                    and .platform.architecture == $arch
                    and .digest == $digest)]
          | length
        ) == 1
        and (
          [(.manifests // [])[]
           | select(.platform.os != "unknown"
                    and .platform.architecture != "unknown")]
          | length
        ) == 1
      ' <<<"${JSON}" >/dev/null

    printf 'GHCR_PLATFORM_VERIFY=PASS\n'
    printf 'REF=%s\n' "${REF}"
    printf 'PLATFORM=%s/%s\n' "${EXPECTED_OS}" "${EXPECTED_ARCH}"
    printf 'CHILD_DIGEST=%s\n' "${EXPECTED_CHILD_DIGEST}"
    ;;

  *)
    usage
    ;;
esac
