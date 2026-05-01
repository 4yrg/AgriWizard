#!/bin/bash

BASE_URL="https://agriwizard-prod-gateway.yellowocean-38e04fed.centralindia.azurecontainerapps.io"

services=(
    "iam"
    "hardware"
    "analytics"
    "weather"
    "notifications"
)

echo "Testing Health Endpoints via Gateway..."
echo "---------------------------------------"

# Test Gateway Health
res=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/health")
echo "Gateway Health (/health): $res"

for service in "${services[@]}"; do
    res=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/v1/$service/health")
    echo "$service Health (/api/v1/$service/health): $res"
done

echo ""
echo "Testing IAM Login..."
echo "--------------------"

# Try to login with the default admin credentials
# email: admin@agriwizard.local
# password: admin123

LOGIN_RES=$(curl -s -X POST "$BASE_URL/api/v1/iam/login" \
     -H "Content-Type: application/json" \
     -d "{\"email\": \"admin@agriwizard.local\", \"password\": \"admin123\"}")

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/v1/iam/login" \
     -H "Content-Type: application/json" \
     -d "{\"email\": \"admin@agriwizard.local\", \"password\": \"admin123\"}")

if [ "$HTTP_CODE" == "200" ]; then
    echo "Login Successful (200)"
    TOKEN=$(echo $LOGIN_RES | grep -oP '"token":"\K[^"]+')
    
    echo ""
    echo "Testing Protected Endpoints..."
    echo "------------------------------"
    
    # IAM Profile
    res=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" "$BASE_URL/api/v1/iam/profile")
    echo "IAM Profile: $res"
    
    # Hardware Equipments
    res=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" "$BASE_URL/api/v1/hardware/equipments")
    echo "Hardware Equipments: $res"
    
    # Hardware Sensors
    res=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" "$BASE_URL/api/v1/hardware/sensors")
    echo "Hardware Sensors: $res"
    
    # Weather Current
    res=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" "$BASE_URL/api/v1/weather/current?lat=6.9271&lon=79.8612")
    echo "Weather Current: $res"

else
    echo "Login Failed with code $HTTP_CODE"
    echo "Response: $LOGIN_RES"
fi
