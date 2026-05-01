#!/bin/bash

BASE_URL="https://agriwizard-prod-gateway.yellowocean-38e04fed.centralindia.azurecontainerapps.io"

echo "Logging in as admin..."
LOGIN_RES=$(curl -s -X POST "$BASE_URL/api/v1/iam/login" \
     -H "Content-Type: application/json" \
     -d "{\"email\": \"admin@agriwizard.local\", \"password\": \"admin123\"}")

TOKEN=$(echo $LOGIN_RES | grep -oP '"token":"\K[^"]+')

if [ -z "$TOKEN" ]; then
    echo "Login failed!"
    echo "Response: $LOGIN_RES"
    exit 1
fi

echo "Login successful. Testing equipment creation..."

# Generate a unique serial to avoid conflicts
SERIAL="test-pump-$(date +%s)"

CREATE_PAYLOAD=$(cat <<EOF
{
  "serial": "$SERIAL",
  "name": "Test Water Pump",
  "supported_operations": ["ON", "OFF"]
}
EOF
)

echo "Payload: $CREATE_PAYLOAD"

res=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/v1/hardware/equipments" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $TOKEN" \
     -d "$CREATE_PAYLOAD")

echo "Equipment Creation Response Code: $res"

if [ "$res" == "201" ]; then
    echo "Success! Equipment created."
    # Optionally verify by listing
    echo "Verifying by listing equipment..."
    LIST_RES=$(curl -s -H "Authorization: Bearer $TOKEN" "$BASE_URL/api/v1/hardware/equipments")
    echo "List contains new equipment: $(echo $LIST_RES | grep -o "$SERIAL")"
else
    echo "Failed! Response code: $res"
    # Get the error message if possible
    ERROR_RES=$(curl -s -X POST "$BASE_URL/api/v1/hardware/equipments" \
         -H "Content-Type: application/json" \
         -H "Authorization: Bearer $TOKEN" \
         -d "$CREATE_PAYLOAD")
    echo "Error details: $ERROR_RES"
fi
