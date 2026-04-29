#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="${IMAGE_NAME:-joposcragent/flyway}"

if [[ -n "${IMAGE_VERSION:-}" ]]; then
	VERSION="$IMAGE_VERSION"
else
	VERSION="$(tr -d '[:space:]' < "${SCRIPT_DIR}/version")"
fi

if [[ -z "$VERSION" ]]; then
	echo "error: empty version (set IMAGE_VERSION or fix ${SCRIPT_DIR}/version)" >&2
	exit 1
fi

docker build -t "${IMAGE_NAME}:${VERSION}" "${SCRIPT_DIR}"
docker tag "${IMAGE_NAME}:${VERSION}" "${IMAGE_NAME}:latest"

echo "Built ${IMAGE_NAME}:${VERSION} and tagged ${IMAGE_NAME}:latest"
