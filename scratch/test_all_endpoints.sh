#!/bin/bash

BASE_URL="https://agriwizard-prod-gateway.yellowocean-38e04fed.centralindia.azurecontainerapps.io"

echo "=================================================================="
echo "   AgriWizard API Gateway: Comprehensive Endpoint Verification   "
echo "=================================================================="
echo ""

# Helper to print results
check_res() {
    local name=$1
    local code=$2
    if [[ "$code" =~ ^2 ]]; then
        echo "✅ [${code}] $name"
    else
        echo "❌ [${code}] $name"
    fi
}

# 1. Health Checks
echo "--- 🏥 Health Checks ---"
check_res "Gateway" $(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/health")
check_res "IAM" $(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/v1/iam/health")
check_res "Hardware" $(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/v1/hardware/health")
check_res "Analytics" $(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/v1/analytics/health")
check_res "Weather" $(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/v1/weather/health")
check_res "Notifications" $(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/v1/notifications/health")
echo ""

# 2. IAM Authentication
echo "--- 🔐 IAM (Authentication) ---"
LOGIN_RES=$(curl -s -X POST "$BASE_URL/api/v1/iam/login" \
     -H "Content-Type: application/json" \
     -d '{"email": "admin@agriwizard.local", "password": "admin123"}')

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/v1/iam/login" \
     -H "Content-Type: application/json" \
     -d '{"email": "admin@agriwizard.local", "password": "admin123"}')

check_res "Login (admin)" "$HTTP_CODE"

if [ "$HTTP_CODE" != "200" ]; then
    echo "Aborting tests: Login failed."
    exit 1
fi

TOKEN=$(echo $LOGIN_RES | grep -oP '"token":"\K[^"]+')

# IAM Profile
check_res "Get Profile" $(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" "$BASE_URL/api/v1/iam/profile")
check_res "Introspect" $(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" "$BASE_URL/api/v1/iam/introspect")
echo ""

# 3. Hardware Service
echo "--- 🚜 Hardware Service ---"
# Create Equipment
SERIAL="pump-$(date +%s)"
check_res "Create Equipment" $(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/v1/hardware/equipments" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $TOKEN" \
     -d "{\"serial\": \"$SERIAL\", \"name\": \"Smart Pump\", \"supported_operations\": [\"ON\", \"OFF\"]}")

# List Equipments
check_res "List Equipments" $(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" "$BASE_URL/api/v1/hardware/equipments")

# Create Parameter
PARAM_ID="soil_moisture_$(date +%s)"
check_res "Create Parameter" $(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/v1/hardware/parameters" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $TOKEN" \
     -d "{\"id\": \"$PARAM_ID\", \"unit\": \"%\", \"description\": \"Soil moisture\"}")

check_res "List Parameters" $(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" "$BASE_URL/api/v1/hardware/parameters")
echo ""

# 4. Analytics Service
echo "--- 📊 Analytics Service ---"
check_res "Upsert Threshold" $(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/v1/analytics/thresholds" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $TOKEN" \
     -d "{\"parameter_id\": \"$PARAM_ID\", \"min_value\": 20, \"max_value\": 80, \"is_enabled\": true}")

check_res "Get Threshold" $(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" "$BASE_URL/api/v1/analytics/thresholds/$PARAM_ID")
echo ""

# 5. Weather Service
echo "--- 🌤️ Weather Service ---"
check_res "Current Weather" $(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" "$BASE_URL/api/v1/weather/current?lat=6.9271&lon=79.8612")
check_res "Forecast" $(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" "$BASE_URL/api/v1/weather/forecast?lat=6.9271&lon=79.8612")
check_res "Recommendations" $(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" "$BASE_URL/api/v1/weather/recommendations?lat=6.9271&lon=79.8612")
echo ""

# 6. Notifications Service
echo "--- 🔔 Notifications Service ---"
check_res "Send Notification" $(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/v1/notifications" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $TOKEN" \
     -d '{"recipient": "admin@agriwizard.local", "subject": "Test Notification", "body": "This is a test from the gateway verification script."}')

check_res "List Notifications" $(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" "$BASE_URL/api/v1/notifications")
check_res "List Templates" $(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" "$BASE_URL/api/v1/notifications/templates")
echo ""

echo "Verification Complete."
