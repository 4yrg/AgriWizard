#!/bin/bash
set -e

# scripts/test-mqtt-connectivity.sh
# Validates connectivity to the managed MQTT broker

MQTT_HOST=$1
MQTT_PORT=${2:-8883}
MQTT_USER=$3
MQTT_PASS=$4

if [ -z "$MQTT_HOST" ]; then
  echo "Usage: ./test-mqtt-connectivity.sh <host> <port> <user> <pass>"
  exit 1
fi

echo "Testing MQTT connectivity to $MQTT_HOST:$MQTT_PORT..."

# Use mosquitto_pub for a simple check if available, else use a small python script
if command -v mosquitto_pub &> /dev/null; then
  mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -u "$MQTT_USER" -P "$MQTT_PASS" -t "test/connection" -m "AgriWizard Health Check" --tls-version tlsv1.2 -d
  if [ $? -eq 0 ]; then
    echo "✓ MQTT Connection Successful"
  else
    echo "✗ MQTT Connection Failed"
    exit 1
  fi
else
  echo "mosquitto_pub not found. Falling back to python3 check..."
  python3 -c "
import paho.mqtt.client as mqtt
import ssl
import sys

client = mqtt.Client()
client.username_pw_set('$MQTT_USER', '$MQTT_PASS')
client.tls_set(cert_reqs=ssl.CERT_REQUIRED, tls_version=ssl.PROTOCOL_TLSv1_2)

try:
    client.connect('$MQTT_HOST', int('$MQTT_PORT'), 60)
    print('✓ MQTT Connection Successful')
    sys.exit(0)
except Exception as e:
    print(f'✗ MQTT Connection Failed: {e}')
    sys.exit(1)
"
fi
