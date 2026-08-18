#!/usr/bin/env bash
# Copy this repo's env overlay into a backstage-performance checkout.
# Usage: ./scripts/apply-overlay.sh /path/to/backstage-performance
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARNESS="${1:?Usage: $0 /path/to/backstage-performance}"

if [ ! -f "${HARNESS}/ci-scripts/setup.sh" ]; then
  echo "Not a backstage-performance checkout: ${HARNESS}" >&2
  exit 1
fi

DEST="${HARNESS}/scenarios/isolation"
mkdir -p "${DEST}"

cp "${REPO_ROOT}/env/combined-xl-reuse-github.env" "${DEST}/combined-xl-reuse-github.env"
echo "Installed ${DEST}/combined-xl-reuse-github.env"
echo ""
echo "Next:"
echo "  1. cp env/.setenv.local.example ${HARNESS}/.setenv.local  # then edit secrets paths"
echo "  2. export RHDH_NAMESPACE=your-namespace"
echo "  3. See README.md for push-github-xl + run.sh steps"
