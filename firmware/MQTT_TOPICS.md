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

- `agriwizard/sensor/<SENSOR_SERIAL>/telemetry`
  - DHT11 + soil moisture telemetry payload.

## Publish (equipment status)

- `agriwizard/equipment/<FAN_EQUIPMENT_SERIAL>/command/status`
  - Fan ON/OFF status updates.

- `agriwizard/equipment/<PUMP_EQUIPMENT_SERIAL>/command/status`
  - Pump ON/OFF status updates.

## Payload format used by firmware

### Command payload (incoming)

```json
{
  "equipment_id": "<equipment_serial>",
  "operation": "ON",
  "payload": {},
  "issued_at": "2026-03-22T10:00:00Z"
}
```

### Telemetry payload (outgoing)

```json
{
  "sensor_id": "<sensor_serial>",
  "readings": [
    { "parameter_id": "air_temp_c", "value": 29.4 },
    { "parameter_id": "air_humidity_pct", "value": 73.1 },
    { "parameter_id": "soil_moisture_pct", "value": 41.8 }
  ]
}
```

### One sensor sending 2 or more parameters (required format)

Use a **single telemetry publish** per sensor cycle, and include each measured metric as a separate object inside `readings`.

```json
{
  "sensor_id": "soil_probe_zone_a",
  "readings": [
    { "parameter_id": "soil_moisture_pct", "value": 41.8 },
    { "parameter_id": "soil_temp_c", "value": 28.2 },
    { "parameter_id": "ec_ms_cm", "value": 1.43 }
  ],
  "timestamp": "2026-04-26T09:35:00Z"
}
```

ArduinoJson shape (same as `firmware.ino` pattern):

```cpp
StaticJsonDocument<512> doc;
doc["sensor_id"] = SENSOR_ID;

JsonArray readings = doc.createNestedArray("readings");

JsonObject r1 = readings.createNestedObject();
r1["parameter_id"] = "soil_moisture_pct";
r1["value"] = soilMoisture;

JsonObject r2 = readings.createNestedObject();
r2["parameter_id"] = "soil_temp_c";
r2["value"] = soilTemp;

JsonObject r3 = readings.createNestedObject();
r3["parameter_id"] = "ec_ms_cm";
r3["value"] = soilEc;

doc["timestamp"] = "2026-04-26T09:35:00Z";

char payload[640];
size_t n = serializeJson(doc, payload, sizeof(payload));
mqttClient.publish(sensorTelemetryTopic.c_str(), payload, n, false);
```

### Equipment status payload (outgoing)

```json
{
  "equipment_id": "<equipment_serial>",
  "status": "ON"
}
```
