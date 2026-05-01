#!/bin/bash
set -e

# scripts/healthcheck.sh
# Checks health of all local/deployed services

BASE_URL=${1:-"http://localhost:8080"}

services=("/health" "/api/v1/iam/health" "/api/v1/hardware/health" "/api/v1/analytics/health" "/api/v1/weather/health" "/api/v1/notification/health")

echo "Checking health for services at $BASE_URL..."

for svc in "${services[@]}"; do
  echo -n "Checking $svc... "
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL$svc")
  if [ "$STATUS" -eq 200 ]; then
    echo "✓ OK"
  else
    echo "✗ FAILED ($STATUS)"
    # Don't exit immediately, check others
  fi
done
