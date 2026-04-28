# AgriWizard — IoT Production Design

## Overview

AgriWizard uses Azure IoT Hub for production IoT connectivity to manage greenhouse sensors and equipment.

---

## IoT Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│              AgriWizard IoT Architecture                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐      │
│  │            Azure IoT Hub                           │      │
│  │  ┌─────────────────────────────────────────────┐  │      │
│  │  │  Device Registry (Device IDs)              │  │      │
│  │  │  - sensor-001 ... sensor-256               │  │      │
│  │  │  - pump-001 ... pump-064                  │  │      │
│  │  │  - fan-001 ... fan-064                   │  │      │
│  │  │  - light-001 ... light-064             │  │      │
│  │  └─────────────────────────────────────────────┘  │      │
│  └──────────────────────┬──────────────────────────────┘      │
│                       │                                  │
│         ┌─────────────┼─────────────┐                   │
│         ▼             ▼             ▼                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │ MQTT    │  │ AMQP    │  │ HTTP    │              │
│  │ 8883    │  │ 5671    │  │ 443     │              │
│  └──────────┘  └──────────┘  └──────────┘              │
│         │             │             │                        │
│         └─────────────┼─────────────┘                        │
│                       │                                  │
│  ┌──────────────────┴──────────────────────────────┐       │
│  │         Hardware Service (Container App)         │       │
│  │  ┌─────────────────────────────────────┐  │       │
│  │  │  Device Message Router               │  │       │
│  │  │  - Parse telemetry                 │  │       │
│  │  │  - Validate readings              │  │       │
│  │  │  - Store to database               │  │       │
│  │  │  - Trigger rules                  │  │       │
│  │  └─────────────────────────────────────┘  │       │
│  └────────────────────┬──────────────────────┘       │
│                       │                               │
│  ┌───────────────────┼───────────────────────────┐   │
│  │                   ▼                           │   │
│  │  ┌──────────┐  ┌──────────┐                 │   │
│  │  │Analytics │  │ Service Bus                   │   │
│  │  │Service  │  │ - telemetry-ingest          │   │
│  │  │         │  │ - equipment-commands         │   │
│  │  └──────────┘  └───────────────────────────┘   │
│                                                │
└─────────────────────────────────────────────────────────────┘

                    ▲
                    │ Commands
                    │
┌───────────────────┴───────────────────────────────┐
│            Greenhouse Devices                  │
│  ┌────────────────────────────────────────┐    │
│  │  Sensors (Temperature, Humidity, etc.) │    │
│  │  - Wired or Wireless                   │    │
│  │  - MQTT client                       │    │
│  └────────────────────────────────────────┘    │
│  ┌────────────────────────────────────────┐    │
│  │  Equipment (Pumps, Fans, Lights)      │    │
│  │  - Controlled via IoT Hub commands   │    │
│  │  - Status reporting                 │    │
│  └────────────────────────────────────────┘    │
└────────────────────────────────────────────────┘
```

---

## Device Types

| Device Type | Description | Properties |
|------------|-------------|------------|
| `sensor` | Environmental sensor | type, location, hardware_id |
| `pump` | Water pump | capacity, status |
| `fan` | Ventilation fan | speed_levels, status |
| `light` | Grow lights | spectrum, intensity |
| `valve` | Solenoid valve | normally_open, status |

### Device Properties (Device Twin)

```json
{
  "deviceId": "sensor-001",
  "deviceType": "sensor",
  "properties": {
    "desired": {
      "reportingInterval": 60000,
      "threshold": {
        "temperature": { "min": 18, "max": 30 },
        "humidity": { "min": 40, "max": 80 }
      }
    },
    "reported": {
      "firmware": "1.0.0",
      "battery": 85,
      "lastSeen": "2024-01-15T10:30:00Z"
    }
  }
}
```

---

## Message Protocol

### Telemetry (Device → Cloud)

```json
{
  "deviceId": "sensor-001",
  "messageId": "msg-001",
  "timestamp": "2024-01-15T10:30:00Z",
  "readings": [
    { "type": "temperature", "value": 24.5, "unit": "C" },
    { "type": "humidity", "value": 65, "unit": "%" },
    { "type": "soil_moisture", "value": 42, "unit": "%" }
  ]
}
```

### Commands (Cloud → Device)

```json
{
  "commandName": "setPump",
  "commandId": "cmd-001",
  "payload": {
    "pumpId": "pump-001",
    "action": "on",
    "duration": 300
  }
}
```

### Response (Device → Cloud)

```json
{
  "commandId": "cmd-001",
  "status": "success",
  "result": {
    "pumpId": "pump-001",
    "state": "running",
    "runtime": 300
  }
}
```

---

## Azure IoT Hub Configuration

### SKU Options

| Tier | Devices | Messages/Day | Features |
|------|---------|-------------|----------|
| **Free** | 500 | 8000 | Basic |
| **Standard** | Unlimited | 200K+ | Full |
| **Basic** | Unlimited | 400K | Limited |

### Recommended: Standard (S1)

- $25/month for 400K messages
- Unlimited devices
- Full device management
- Device twins
- Jobs scheduling

### Endpoints

| Protocol | Port | Use |
|---------|------|-----|
| MQTT | 8883 | Devices |
| AMQP | 5671 | Back-end |
| HTTPS | 443 | REST API |

---

## Hardware Service Integration

### Current Flow

```go
// Hardware Service - IoT Hub Client
package main

import (
    "github.com/Azure/azure-sdk-for-go/sdk/iot/aziothub"
    "github.com/Azure/azure-sdk-for-go/sdk/iot/azd2c"
)

func main() {
    // Initialize IoT Hub client
    client, _ := aziothub.NewClientFromConnectionString(
        os.Getenv("IOT_HUB_CONNECTION"),
    )

    // Receive telemetry
    receiver, _ := client.NewTelemetryConsumer()
    
    for {
        msg, err := receiver.Receive()
        if err != nil {
            continue
        }
        
        // Parse and process
        telemetry := parseTelemetry(msg)
        saveToDatabase(telemetry)
        
        // Trigger analytics
        evaluateRules(telemetry)
    }
}
```

### Send Commands

```go
func sendCommand(client *aziothub.Client, deviceID, command string, payload interface{}) error {
    method := aziothub.Method{
        Name:    command,
        Payload: payload,
        Timeout: 30 * time.Second,
    }
    
    resp, err := client.InvokeDeviceMethod(deviceID, method)
    if err != nil {
        return err
    }
    
    return json.Unmarshal(resp.Payload, &result)
}
```

---

## Device Provisioning

### Option 1: Manual Registration

```bash
# Register device via Azure CLI
az iot hub device-identity create \
  --hub-name agriwizard-prod-iothub \
  --device-id sensor-001 \
  --device-type sensor

# Get connection string
az iot hub device-identity connection-string show \
  --hub-name agriwizard-prod-iothub \
  --device-id sensor-001
```

### Option 2: Device Provisioning Service (DPS)

For automated provisioning:

```hcl
resource "azurerm_iot_dps" "main" {
  name                = "agriwizard-prod-dps"
  resource_group_name = azurerm_resource_group.main.name
  location           = azurerm_resource_group.main.location
  sku                = "Standard"
  linked_hub {
    iothub_name = azurerm_iothub.main.name
    weight     = 100
  }
}
```

### Device Authentication

| Method | Use Case |
|--------|----------|
| Symmetric Key | Simple deployment |
| X.509 CA | Production (secure) |
| TPM | High security |

---

## Offline Support

### Store-and-Forward

IoT Hub stores messages when devices are offline:
- Up to 7 days retention
- Automatic retry on reconnect

### Edge Configuration

For critical equipment, use Azure IoT Edge:

```yaml
# IoT Edge deployment
name: greenhouse-edge
modules:
  - name: temp-sensor
    image: mcr.microsoft.com/azure-cli:latest
    createOptions:
      env:
        MQTT_TOPIC: agriwizard/sensors/+
routes:
  sensorToCloud: FROM /messages/* INTO $upstream
  telemetryToAnalytics: FROM /messages/* WHERE (CAST(NOW() AS datetime) - enqueuedTime > 0) INTO BrokeredEndpoint("/modules/analytics-service/inputs/telemetry")
```

---

## Scalability

### Message Flow

```
Devices: 500 sensors × 1 msg/min = 30K messages/day

IoT Hub (S1):
- 400K messages/day limit ✓
- Good for MVP + growth

Scaling:
┌────────────────────────────────────────────┐
│        Traffic Growth Planning            │
├────────────────────────────────────────────┤
│ 500 devices  →  S1 ($25/month)        │
│ 2000 devices → S2 ($50/month)        │
│ 10000+      → S3 ($250/month)       │
└────────────────────────────────────────────┘
```

---

## Security

### Device Security

- **Authentication**: X.509 certificates
- **Transport**: TLS 1.2
- **IoT Hub**: Managed identity
- **Firewall**: Restrict inbound IPs

### Best Practices

1. Use DPS for auto-provisioning
2. Rotate connection strings
3. Use device twins for configuration
4. Implement message validation
5. Set up alerts for offline devices
6. Monitor message latency
7. Plan for device decommissioning

---

## Monitoring

### IoT Hub Metrics

| Metric | Alert |
|--------|-------|
| Devices connected | < 80% active |
| Message latency | > 5 seconds |
| Device twin updates | Failed > 1% |
| Messaging quota | > 80% used |

### Log Analytics

```kusto
// Device connection events
AzureDiagnostics
| where ResourceType == "IOTHUBS"
| where OperationName contains "device"
| summarize count() by bin(TimeGenerated, 1h)
```

---

## Migration from HiveMQ

| Component | HiveMQ Cloud | Azure IoT Hub |
|-----------|-------------|---------------|
| Protocol | MQTT | MQTT, AMQP, HTTP |
| Device Mgmt | Basic | Full (twins, jobs) |
| Offline | Limited | Store & forward |
| Provisioning | Manual | DPS |
| Security | TLS | X.509, Managed ID |

**Migration Steps:**

1. Create IoT Hub
2. Register devices
3. Update device firmware
4. Update Hardware Service
5. Configure DPS (optional)
6. Test and switch
7. Decommission HiveMQ