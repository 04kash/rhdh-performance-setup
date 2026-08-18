#!/bin/bash
# Generate and push 70k catalog entities (35k API + 35k Component) to the scratch
# GitHub repo with batched git pushes and rate-limit checks.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CI_SECRETS_DIR="${CI_SECRETS_DIR:-/usr/local/ci-secrets/backstage-performance}"

export GITHUB_TOKEN="$(cat "${CI_SECRETS_DIR}/github.token")"
export GITHUB_USER="$(cat "${CI_SECRETS_DIR}/github.user")"
export GITHUB_REPO="$(cat "${CI_SECRETS_DIR}/github.repo")"

# XL counts (same as github-xl.env / combined-xl)
export API_COUNT=35000
export COMPONENT_COUNT=35000
export GROUP_COUNT=25
export RBAC_POLICY=all_groups_admin_inherited

# Gentle on GitHub: 10 shard files (~5k entities) per push, 60s between pushes.
export GITHUB_UPLOAD_BATCH_SIZE="${GITHUB_UPLOAD_BATCH_SIZE:-10}"
export GITHUB_UPLOAD_SLEEP_SECONDS="${GITHUB_UPLOAD_SLEEP_SECONDS:-60}"
export GITHUB_RATE_LIMIT_MIN_REMAINING="${GITHUB_RATE_LIMIT_MIN_REMAINING:-200}"
export COMPONENT_SHARD_SIZE="${COMPONENT_SHARD_SIZE:-500}"

export TMP_DIR="${ROOT}/.tmp"
export WORKDIR="${ROOT}/ci-scripts/rhdh-setup"
mkdir -p "$TMP_DIR"
rm -f "$TMP_DIR"/api-*.yaml "$TMP_DIR"/component-*.yaml

LOG="${ROOT}/github-xl-push.log"
echo "=== $(date -u +%FT%TZ) GitHub XL push started ===" | tee "$LOG"
echo "repo=${GITHUB_REPO} batch=${GITHUB_UPLOAD_BATCH_SIZE} sleep=${GITHUB_UPLOAD_SLEEP_SECONDS}s" | tee -a "$LOG"

cd "$WORKDIR"
# shellcheck disable=SC1091
source ./common.sh
# shellcheck disable=SC1091
source ./create_resource.sh

log_info "Generating and uploading ${COMPONENT_COUNT} components"
create_per_grp create_cmp COMPONENT_COUNT | tee -a "$LOG"

log_info "Generating and uploading ${API_COUNT} APIs"
create_per_grp create_api API_COUNT | tee -a "$LOG"

echo "=== $(date -u +%FT%TZ) DONE ===" | tee -a "$LOG"
echo "locations: $(wc -l < "${TMP_DIR}/locations.yaml") lines in ${TMP_DIR}/locations.yaml" | tee -a "$LOG"
yq '.locations | length' "${TMP_DIR}/locations.yaml" | tee -a "$LOG"
echo ""
echo "Save locations for reuse: cp ${TMP_DIR}/locations.yaml scenarios/isolation/combined-xl-locations.yaml"
