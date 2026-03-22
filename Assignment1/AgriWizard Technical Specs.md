# **AgriWizard: Technical Specifications**

This document provides the detailed technical specifications for the core services within the AgriWizard ecosystem: the **Hardware Monitor & Controller Service**, the **AgriLogic Decision & Analytics Service**, and the **External Weather Intelligence Service**.

## **Part 1: Hardware Monitor & Controller Service**

### **1\. Overview**

A specialized microservice designed to bridge the physical IoT layer with the cloud. It manages two primary entities: **Sensors** (data providers) and **Equipments** (actuators/controllers). It handles dynamic MQTT topic subscriptions and provides a RESTful interface for external services.

### **2\. Core Data Models**

#### **A. Equipment (Actuator/Controller)**

*Used for devices that perform physical actions (e.g., Water Pump, Fan, Solenoid Valve).*

* **Equipment ID**: Unique string/UUID.  
* **Name**: Human-readable label (e.g., "Main Water Pump").  
* **Supported Operations**: Array of strings (e.g., \['ON', 'OFF', 'REVERSE'\]).  
* **MQTT Topic**: The specific topic for sending command payloads.  
* **REST API**: Endpoint for direct synchronous control triggers.  
* **Current Status**: Enum representing state (ON, OFF, LOCKED, DISABLED).

#### **B. Sensor (Data Provider)**

*Used for devices providing environmental telemetry (e.g., Soil Moisture, pH, DHT11).*

* **Sensor ID**: Unique string/UUID.  
* **Name**: Display name (e.g., "Zone A Soil Probe").  
* **Parameters**: List of Parameter IDs associated with this sensor's output.  
* **MQTT Topic**: The topic this service listens to for incoming telemetry.  
* **Update Frequency**: Desired interval for data reporting.

#### **C. Parameter (Metric Definition)**

*Specific data points measured by sensors, allowing for dynamic expansion.*

* **Parameter ID**: Unique key (e.g., soil\_moisture\_pct).  
* **Unit**: Unit of measurement (e.g., %, Celsius).  
* **Description**: Metadata about the metric.

#### **D. Raw Sensor Data (Telemetry Log)**

* **Sensor ID**: ID of the originating sensor.  
* **Parameter ID**: Which specific metric was measured.  
* **Value**: The float/numeric reading.  
* **Timestamp**: RFC3339 formatted date and time.

### **3\. Persistent Storage Schema (PostgreSQL)**

| Table | Key Columns |
| :---- | :---- |
| **equipments** | id (PK), name, operations (TEXT\[\]), mqtt\_topic, api\_url, current\_status |
| **sensors** | id (PK), name, parameter\_ids (TEXT\[\]), mqtt\_topic, api\_url |
| **parameters** | id (PK), unit, description |
| **raw\_sensor\_data** | id (SERIAL PK), sensor\_id, parameter\_id, value, timestamp |

### **4\. API Endpoints**

* POST /api/hardware/equipments: Register a new equipment controller.  
* GET /api/hardware/equipments: Retrieve all registered equipment.  
* POST /api/hardware/sensors: Provision a new sensor device.  
* GET /api/hardware/sensors: Get all sensors including parameters.  
* POST /api/hardware/control/{id}: Dispatch an operation to equipment (triggers MQTT).

## **Part 2: AgriLogic Decision & Analytics Service**

### **1\. Overview**

The **AgriLogic** service acts as the intelligence layer. It consumes raw telemetry from the Hardware service to generate summaries and manages automation rules (thresholds).

### **2\. Core Data Models**

#### **A. Threshold Configuration**

* **Threshold ID**: Unique UUID.  
* **Parameter ID**: Linked metric (e.g., soil\_moisture\_pct).  
* **Min Value**: Lower bound trigger.  
* **Max Value**: Upper bound trigger.  
* **Enabled**: Boolean toggle.

#### **B. Automation Rule (Action Mapping)**

* **Rule ID**: Unique identifier.  
* **Threshold ID**: Foreign key to configuration.  
* **Equipment ID**: Target hardware (e.g., pump\_01).  
* **Low Action**: Command to send if value \< Min (e.g., TURN\_ON).  
* **High Action**: Command to send if value \> Max (e.g., TURN\_OFF).

### **3\. Persistent Storage Schema (PostgreSQL)**

| Table | Key Columns |
| :---- | :---- |
| **thresholds** | id (PK), parameter\_id, min\_value, max\_value, is\_enabled |
| **automation\_rules** | id (PK), threshold\_id, equipment\_id, low\_action, high\_action |
| **daily\_summaries** | id (PK), parameter\_id, avg\_value, min\_recorded, max\_recorded, date |

### **4\. API Endpoints**

* POST /api/analytics/thresholds: Create or update a threshold range.  
* GET /api/analytics/thresholds/{parameterId}: Fetch specific bounds for a metric.  
* GET /api/analytics/rules/{parameterId}: Retrieve automation rules linked to a parameter threshold.  
* GET /api/analytics/decisions/summary: Retrieve the "Decision Table".  
* POST /api/analytics/ingest: Receives raw data from Hardware Service for processing.

## **Part 3: External Weather Intelligence Service**

### **1\. Overview**

This service adds a "Smart Advisor" layer by integrating with third-party cloud APIs (e.g., OpenWeatherMap). It provides real-time ambient context to help the system decide if scheduled operations should be adjusted based on external conditions.

### **2\. Core Data Models**

#### **A. Weather Forecast Data**

* **Location**: Latitude and Longitude.  
* **Forecast Timestamp**: Future time window.  
* **Probability of Precipitation (PoP)**: Percentage chance of rain.  
* **External Temp/Humidity**: Outside ambient conditions.

#### **B. Weather Alert**

* **Type**: Extreme heat, storm, frost warning.  
* **Severity**: Level of urgency for notifications.

### **3\. API Endpoints**

* GET /api/weather/current: Returns live local weather data.  
* GET /api/weather/forecast: Provides a 24-hour precipitation and temperature forecast.  
* GET /api/weather/alerts: Checks for active extreme weather warnings in the greenhouse's region.  
* GET /api/weather/recommendations: Provides a "Scale Factor" for irrigation based on temp (e.g., if \> 35°C, return {"scale": 1.2}).

## **Part 4: Service Integration & Logic Loop**

### **1\. Inter-Service Communication Flow**

1. **Rule Retrieval**: Hardware Service calls GET /api/analytics/rules/{parameterId}.  
2. **Weather Awareness**: The Analytics service calls GET /api/weather/forecast. If rain is 90% likely, it may temporarily disable the "Low Moisture" rule to conserve water.  
3. **Execution**: Hardware Service publishes MQTT commands based on the final decision.  
4. **Notification**: Hardware Service calls the **Alert Service** to notify the user of automated actions or weather warnings.

### **2\. Security (IAM Integration)**

Every inter-service request includes a Bearer \<JWT\> token. Each service validates this token with the **IAM Service** before processing.