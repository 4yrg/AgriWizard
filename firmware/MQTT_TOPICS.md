# MQTT Topics (Firmware)

This firmware uses the following MQTT topics.

## Subscribe (commands)

- `agriwizard/equipment/+/command`
  - ESP32 listens to all equipment command topics.

- `agriwizard/equipment/<FAN_EQUIPMENT_ID>/command`
  - Fan command topic (matched by wildcard).

- `agriwizard/equipment/<PUMP_EQUIPMENT_ID>/command`
  - Pump command topic (matched by wildcard).

## Publish (telemetry)

- `agriwizard/sensor/<SENSOR_ID>/telemetry`
  - DHT11 + soil moisture telemetry payload.

## Publish (equipment status)

- `agriwizard/equipment/<FAN_EQUIPMENT_ID>/command/status`
  - Fan ON/OFF status updates.

- `agriwizard/equipment/<PUMP_EQUIPMENT_ID>/command/status`
  - Pump ON/OFF status updates.

## Payload format used by firmware

### Command payload (incoming)

```json
{
  "equipment_id": "<equipment_id>",
  "operation": "ON",
  "payload": {},
  "issued_at": "2026-03-22T10:00:00Z"
}
```

### Telemetry payload (outgoing)

```json
{
  "sensor_id": "<sensor_id>",
  "readings": [
    { "parameter_id": "air_temp_c", "value": 29.4 },
    { "parameter_id": "air_humidity_pct", "value": 73.1 },
    { "parameter_id": "soil_moisture_pct", "value": 41.8 }
  ]
}
```

### Equipment status payload (outgoing)

```json
{
  "equipment_id": "<equipment_id>",
  "status": "ON"
}
```
