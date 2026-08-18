#!/usr/bin/env bash
# Patch stock backstage-performance with vendored harness changes + isolation scenarios.
# Usage: ./scripts/apply-overlay.sh /path/to/backstage-performance
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARNESS="${1:?Usage: $0 /path/to/backstage-performance}"
PATCH="${REPO_ROOT}/harness-patches/0001-harness-core.patch"
SCENARIOS_SRC="${REPO_ROOT}/harness-patches/scenarios/isolation"
SCENARIOS_DEST="${HARNESS}/scenarios/isolation"

if [ ! -f "${HARNESS}/ci-scripts/setup.sh" ]; then
  echo "Not a backstage-performance checkout: ${HARNESS}" >&2
  exit 1
fi

if [ ! -f "${PATCH}" ]; then
  echo "Missing patch: ${PATCH}" >&2
  exit 1
fi

cd "${HARNESS}"

if git apply --check "${PATCH}" 2>/dev/null; then
  git apply "${PATCH}"
  echo "Applied ${PATCH}"
elif git apply --reverse --check "${PATCH}" 2>/dev/null; then
  echo "Patch already applied — skipping"
else
  echo "ERROR: patch does not apply cleanly. Upstream may have drifted." >&2
  echo "Try: git apply --check ${PATCH}" >&2
  echo "See harness-patches/README.md to refresh the patch." >&2
  exit 1
fi

mkdir -p "${SCENARIOS_DEST}"
cp -a "${SCENARIOS_SRC}/." "${SCENARIOS_DEST}/"
cp "${REPO_ROOT}/env/combined-xl-reuse-github.env" "${SCENARIOS_DEST}/combined-xl-reuse-github.env"
chmod +x "${SCENARIOS_DEST}/run.sh" "${SCENARIOS_DEST}/push-github-xl.sh" 2>/dev/null || true

echo "Installed scenarios/isolation/"
echo ""
echo "Next:"
echo "  1. cp ${REPO_ROOT}/env/.setenv.local.example ${HARNESS}/.setenv.local  # edit secret paths"
echo "  2. export RHDH_NAMESPACE=rhdh-performance-xl"
echo "  3. cd ${HARNESS} && ./scenarios/isolation/push-github-xl.sh"
echo "  4. cp .tmp/locations.yaml scenarios/isolation/combined-xl-locations.yaml"
echo "  5. ./scenarios/isolation/run.sh combined-xl-reuse-github"
