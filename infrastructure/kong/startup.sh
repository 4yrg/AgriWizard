#!/usr/bin/env bash
set -euo pipefail

# DB-less Kong startup helper (local VM/container host)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

cd "${PROJECT_ROOT}"

export KONG_JWT_SHARED_SECRET="${KONG_JWT_SHARED_SECRET:-super-secret-jwt-key-change-in-production}"
export CORS_ALLOW_ORIGIN="${CORS_ALLOW_ORIGIN:-*}"

echo "Starting Kong Gateway in DB-less mode..."
docker compose -f infrastructure/kong/docker-compose.kong.standalone.yml up -d --build

echo "Kong Proxy  : http://localhost:8000"
echo "Kong Admin  : http://localhost:8001"
