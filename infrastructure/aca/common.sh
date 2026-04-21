#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE_DEFAULT="${SCRIPT_DIR}/aca.env"

load_env() {
  local env_file="${1:-${ENV_FILE_DEFAULT}}"
  if [[ ! -f "${env_file}" ]]; then
    echo "Missing env file: ${env_file}" >&2
    echo "Copy ${SCRIPT_DIR}/aca.env.example -> ${env_file} and fill required values." >&2
    exit 1
  fi

  # shellcheck disable=SC1090
  set -a
  source "${env_file}"
  set +a
}

require_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Required command not found: ${cmd}" >&2
    exit 1
  fi
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: ${name}" >&2
    exit 1
  fi
}

az_subscription_context() {
  require_env SUBSCRIPTION_ID
  az account set --subscription "${SUBSCRIPTION_ID}"
}

ensure_file_permissions() {
  chmod +x "${SCRIPT_DIR}"/*.sh >/dev/null 2>&1 || true
}

print_header() {
  local title="$1"
  printf '\n== %s ==\n' "${title}"
}
