#!/bin/bash
set -o nounset
set -o errexit
set -o pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)

scenario="${1:-}"
if [ -z "${scenario}" ]; then
    echo "Usage: $0 <ldap-xl|github-xl|combined-xl|combined-xl-reuse-github>"
    exit 1
fi

env_file="${SCRIPT_DIR}/${scenario}.env"
if [ ! -f "${env_file}" ]; then
    echo "Unknown scenario: ${scenario} (expected ${env_file})"
    exit 1
fi

cd "${REPO_ROOT}"

set -a
# shellcheck disable=SC1090
source "${env_file}"
if [ -f .setenv.local ]; then
    # shellcheck disable=SC1091
    source .setenv.local
fi
set +a

log_name="setup-${scenario}"
echo "Running scenario ${scenario} (SKIP_GITHUB=${SKIP_GITHUB:-false})"

make clean-all |& tee "clean-${log_name}.log"

# PRE_LOAD_DB=false reuses GitHub locations from .tmp; clean-all removes .tmp.
if [ "${PRE_LOAD_DB:-true}" = "false" ] && [ -f "${SCRIPT_DIR}/combined-xl-locations.yaml" ]; then
    mkdir -p "${REPO_ROOT}/.tmp"
    cp "${SCRIPT_DIR}/combined-xl-locations.yaml" "${REPO_ROOT}/.tmp/locations.yaml"
    echo "Restored $(yq '.locations | length' "${REPO_ROOT}/.tmp/locations.yaml") catalog locations after clean-all"
fi

./ci-scripts/setup.sh |& tee "${log_name}.log"
