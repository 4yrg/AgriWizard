#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${1:-${SCRIPT_DIR}/aca.env}"

"${SCRIPT_DIR}/01-bootstrap.sh" "${ENV_FILE}"
"${SCRIPT_DIR}/02-build-push.sh" "${ENV_FILE}"
"${SCRIPT_DIR}/03-deploy-services.sh" "${ENV_FILE}"
"${SCRIPT_DIR}/04-deploy-kong.sh" "${ENV_FILE}"

printf '\nDeployment complete. Run %s/05-test-gateway.sh %s to validate.\n' "${SCRIPT_DIR}" "${ENV_FILE}"
