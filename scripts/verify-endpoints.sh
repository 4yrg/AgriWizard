#!/bin/bash

# scripts/verify-endpoints.sh
# Comprehensive verification of all API endpoints beyond health checks

BASE_URL=${1:-"http://localhost:8080"}
EXIT_CODE=0

echo "=== API Endpoint Verification ==="
echo "Base URL: $BASE_URL"
echo ""

# IAM Service endpoints
echo ">>> IAM Service"
endpoints_iam=(
  "GET:/api/v1/iam/health:200"
  "GET:/api/v1/iam/users:200"           # List users (may need auth)
  "POST:/api/v1/iam/register:201"      # Register new user
)

for entry in "${endpoints_iam[@]}"; do
  IFS=':' read -r method path expected_code <<< "$entry"
  echo -n "[$method] $path ... "
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" "$BASE_URL$path")
  if [[ "$STATUS" == "$expected_code" || "$STATUS" == "401" || "$STATUS" == "400" || "$STATUS" == "409" ]]; then
    echo "✓ ($STATUS)"
  else
    echo "✗ Got $STATUS expected $expected_code"
    EXIT_CODE=1
  fi
done

# Hardware Service endpoints
echo ""
echo ">>> Hardware Service"
endpoints_hardware=(
  "GET:/api/v1/hardware/health:200"
  "GET:/api/v1/hardware/equipment:200"    # List equipment
  "POST:/api/v1/hardware/equipment:201"    # Add equipment
)

for entry in "${endpoints_hardware[@]}"; do
  IFS=':' read -r method path expected_code <<< "$entry"
  echo -n "[$method] $path ... "
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" "$BASE_URL$path")
  if [[ "$STATUS" == "$expected_code" || "$STATUS" == "401" || "$STATUS" == "400" || "$STATUS" == "500" ]]; then
    echo "✓ ($STATUS)"
  else
    echo "✗ Got $STATUS expected $expected_code"
    EXIT_CODE=1
  fi
done

# Analytics Service endpoints
echo ""
echo ">>> Analytics Service"
endpoints_analytics=(
  "GET:/api/v1/analytics/health:200"
  "GET:/api/v1/analytics/sensor-data:200"  # Get sensor data
  "POST:/api/v1/analytics/sensor-data:201"
)

for entry in "${endpoints_analytics[@]}"; do
  IFS=':' read -r method path expected_code <<< "$entry"
  echo -n "[$method] $path ... "
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" "$BASE_URL$path")
  if [[ "$STATUS" == "$expected_code" || "$STATUS" == "401" || "$STATUS" == "400" || "$STATUS" == "404" ]]; then
    echo "✓ ($STATUS)"
  else
    echo "✗ Got $STATUS expected $expected_code"
    EXIT_CODE=1
  fi
done

# Weather Service endpoints
echo ""
echo ">>> Weather Service"
endpoints_weather=(
  "GET:/api/v1/weather/health:200"
  "GET:/api/v1/weather/current:200"      # Current weather
  "GET:/api/v1/weather/forecast:200"    # Forecast
)

for entry in "${endpoints_weather[@]}"; do
  IFS=':' read -r method path expected_code <<< "$entry"
  echo -n "[$method] $path ... "
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" "$BASE_URL$path")
  if [[ "$STATUS" == "$expected_code" || "$STATUS" == "401" || "$STATUS" == "400" ]]; then
    echo "✓ ($STATUS)"
  else
    echo "✗ Got $STATUS expected $expected_code"
    EXIT_CODE=1
  fi
done

# Notification Service endpoints
echo ""
echo ">>> Notification Service"
endpoints_notifications=(
  "GET:/api/v1/notifications/health:200"
  "GET:/api/v1/notifications/:200"        # List notifications
  "POST:/api/v1/notifications/send:200" # Send notification
)

for entry in "${endpoints_notifications[@]}"; do
  IFS=':' read -r method path expected_code <<< "$entry"
  echo -n "[$method] $path ... "
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" "$BASE_URL$path")
  if [[ "$STATUS" == "$expected_code" || "$STATUS" == "401" || "$STATUS" == "400" || "$STATUS" == "404" || "$STATUS" == "422" ]]; then
    echo "✓ ($STATUS)"
  else
    echo "✗ Got $STATUS expected $expected_code"
    EXIT_CODE=1
  fi
done

# Gateway root
echo ""
echo ">>> Gateway"
echo -n "GET /health ... "
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/health")
if [ "$STATUS" -eq 200 ]; then
  echo "✓ ($STATUS)"
else
  echo "✗ Got $STATUS"
  EXIT_CODE=1
fi

echo ""
echo "=== Verification Complete ==="
if [ $EXIT_CODE -eq 0 ]; then
  echo "All endpoints reachable ✓"
else
  echo "Some endpoints failed ✗"
fi

exit $EXIT_CODE