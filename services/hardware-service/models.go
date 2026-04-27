package main

import (
	"database/sql/driver"
	"encoding/json"
	"fmt"
	"time"
)

// StringArray is a helper for PostgreSQL TEXT[] columns.
type StringArray []string

func (a StringArray) Value() (driver.Value, error) {
	if a == nil {
		return "{}", nil
	}
	b, err := json.Marshal(a)
	if err != nil {
		return nil, err
	}
	// Convert JSON array to PG array literal: ["a","b"] -> {"a","b"}
	result := "{" + string(b[1:len(b)-1]) + "}"
	return result, nil
}

func (a *StringArray) Scan(src interface{}) error {
	var s string
	switch v := src.(type) {
	case []byte:
		s = string(v)
	case string:
		s = v
	default:
		return fmt.Errorf("unsupported type: %T", src)
	}
	// Parse PG array literal {a,b,c}
	if s == "{}" || s == "" {
		*a = StringArray{}
		return nil
	}
	s = s[1 : len(s)-1]
	if s == "" {
		*a = StringArray{}
		return nil
	}
	parts := []string{}
	for _, p := range splitPGArray(s) {
		parts = append(parts, p)
	}
	*a = parts
	return nil
}

func splitPGArray(s string) []string {
	var result []string
	var current string
	inQuote := false
	for _, ch := range s {
		switch {
		case ch == '"':
			inQuote = !inQuote
		case ch == ',' && !inQuote:
			result = append(result, current)
			current = ""
		default:
			current += string(ch)
		}
	}
	if current != "" {
		result = append(result, current)
	}
	return result
}

// EquipmentStatus represents the current state of an equipment device.
type EquipmentStatus string

const (
	StatusOn       EquipmentStatus = "ON"
	StatusOff      EquipmentStatus = "OFF"
	StatusLocked   EquipmentStatus = "LOCKED"
	StatusDisabled EquipmentStatus = "DISABLED"
)

// Equipment represents an actuator/controller device (e.g., Water Pump, Fan).
type Equipment struct {
	ID                  string          `json:"id" db:"id"`
	Serial              string          `json:"serial" db:"serial"`
	Name                string          `json:"name" db:"name"`
	SupportedOperations StringArray     `json:"supported_operations" db:"operations"`
	MQTTTopic           string          `json:"mqtt_topic" db:"mqtt_topic"`
	APIURL              string          `json:"api_url" db:"api_url"`
	CurrentStatus       EquipmentStatus `json:"current_status" db:"current_status"`
	CreatedAt           time.Time       `json:"created_at" db:"created_at"`
}

// CreateEquipmentRequest is the payload for registering a new equipment.
type CreateEquipmentRequest struct {
	Serial              string   `json:"serial" binding:"required"`
	Name                string   `json:"name" binding:"required"`
	SupportedOperations []string `json:"supported_operations" binding:"required"`
	APIURL              string   `json:"api_url"`
}

// UpdateEquipmentRequest is the payload for updating an existing equipment.
type UpdateEquipmentRequest struct {
	Serial              string   `json:"serial" binding:"required"`
	Name                string   `json:"name" binding:"required"`
	SupportedOperations []string `json:"supported_operations" binding:"required"`
	APIURL              string   `json:"api_url"`
}

// Sensor represents a data-providing IoT device (e.g., Soil Moisture, pH probe).
type Sensor struct {
	ID              string      `json:"id" db:"id"`
	Serial          string      `json:"serial" db:"serial"`
	Name            string      `json:"name" db:"name"`
	ParameterIDs    StringArray `json:"parameter_ids" db:"parameter_ids"`
	MQTTTopic       string      `json:"mqtt_topic" db:"mqtt_topic"`
	APIURL          string      `json:"api_url" db:"api_url"`
	UpdateFrequency int         `json:"update_frequency_seconds" db:"update_frequency"`
	CreatedAt       time.Time   `json:"created_at" db:"created_at"`
}

// CreateSensorRequest is the payload for provisioning a new sensor.
type CreateSensorRequest struct {
	Serial          string   `json:"serial" binding:"required"`
	Name            string   `json:"name" binding:"required"`
	ParameterIDs    []string `json:"parameter_ids" binding:"required"`
	APIURL          string   `json:"api_url"`
	UpdateFrequency int      `json:"update_frequency_seconds"`
}

// UpdateSensorRequest is the payload for updating an existing sensor.
type UpdateSensorRequest struct {
	Serial          string   `json:"serial" binding:"required"`
	Name            string   `json:"name" binding:"required"`
	ParameterIDs    []string `json:"parameter_ids" binding:"required"`
	APIURL          string   `json:"api_url"`
	UpdateFrequency int      `json:"update_frequency_seconds"`
}

// Parameter defines a specific measurable metric (e.g., soil_moisture_pct).
type Parameter struct {
	ID          string    `json:"id" db:"id"`
	Unit        string    `json:"unit" db:"unit"`
	Description string    `json:"description" db:"description"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
}

// CreateParameterRequest is the payload for defining a new parameter type.
type CreateParameterRequest struct {
	ID          string `json:"id" binding:"required"`
	Unit        string `json:"unit" binding:"required"`
	Description string `json:"description"`
}

// RawSensorData is a single telemetry reading stored as a log entry.
type RawSensorData struct {
	ID          int64     `json:"id" db:"id"`
	SensorID    string    `json:"sensor_id" db:"sensor_id"`
	ParameterID string    `json:"parameter_id" db:"parameter_id"`
	Value       float64   `json:"value" db:"value"`
	Timestamp   time.Time `json:"timestamp" db:"timestamp"`
}

// TelemetryPayload is the MQTT/REST payload format for incoming sensor data.
type TelemetryPayload struct {
	SensorID  string             `json:"sensor_id" binding:"required"`
	Readings  []ParameterReading `json:"readings" binding:"required"`
	Timestamp time.Time          `json:"timestamp"`
}

// ParameterReading is a single parameter value within a telemetry payload.
type ParameterReading struct {
	ParameterID string  `json:"parameter_id"`
	Value       float64 `json:"value"`
}

// ControlCommand is the payload for dispatching a command to equipment.
type ControlCommand struct {
	Operation string                 `json:"operation" binding:"required"`
	Payload   map[string]interface{} `json:"payload,omitempty"`
}

// MQTTCommandMessage is the message published to the equipment MQTT topic.
type MQTTCommandMessage struct {
	EquipmentID string                 `json:"equipment_id"`
	Operation   string                 `json:"operation"`
	Payload     map[string]interface{} `json:"payload,omitempty"`
	IssuedAt    time.Time              `json:"issued_at"`
}

// ErrorResponse is the standard error payload.
type ErrorResponse struct {
	Error   string `json:"error"`
	Message string `json:"message,omitempty"`
}

// SuccessResponse is the standard success payload.
type SuccessResponse struct {
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
}
