package main

import "time"

// Threshold defines the safe operating range for a given parameter.
type Threshold struct {
	ID          string    `json:"id" db:"id"`
	ParameterID string    `json:"parameter_id" db:"parameter_id"`
	MinValue    float64   `json:"min_value" db:"min_value"`
	MaxValue    float64   `json:"max_value" db:"max_value"`
	IsEnabled   bool      `json:"is_enabled" db:"is_enabled"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}

// UpsertThresholdRequest is the payload for creating or updating a threshold.
type UpsertThresholdRequest struct {
	ParameterID string  `json:"parameter_id" binding:"required"`
	MinValue    float64 `json:"min_value"`
	MaxValue    float64 `json:"max_value" binding:"required"`
	IsEnabled   *bool   `json:"is_enabled"`
}

// AutomationRule defines the equipment action triggered when a threshold is breached.
type AutomationRule struct {
	ID          string    `json:"id" db:"id"`
	ThresholdID string    `json:"threshold_id" db:"threshold_id"`
	EquipmentID string    `json:"equipment_id" db:"equipment_id"`
	LowAction   string    `json:"low_action" db:"low_action"`
	HighAction  string    `json:"high_action" db:"high_action"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
}

// CreateRuleRequest is the payload for creating an automation rule.
type CreateRuleRequest struct {
	ThresholdID string `json:"threshold_id" binding:"required"`
	EquipmentID string `json:"equipment_id" binding:"required"`
	LowAction   string `json:"low_action" binding:"required"`
	HighAction  string `json:"high_action" binding:"required"`
}

// DailySummary aggregates sensor data for a given parameter on a given date.
type DailySummary struct {
	ID          int64     `json:"id" db:"id"`
	ParameterID string    `json:"parameter_id" db:"parameter_id"`
	AvgValue    float64   `json:"avg_value" db:"avg_value"`
	MinRecorded float64   `json:"min_recorded" db:"min_recorded"`
	MaxRecorded float64   `json:"max_recorded" db:"max_recorded"`
	Date        time.Time `json:"date" db:"date"`
}

// EquipmentAnalysis tracks performance and usage for a specific device.
type EquipmentAnalysis struct {
	ID              string    `json:"id" db:"id"`
	EquipmentID     string    `json:"equipment_id" db:"equipment_id"`
	Date            time.Time `json:"date" db:"date"`
	UsageCount      int       `json:"usage_count" db:"usage_count"`
	EfficiencyScore float64   `json:"efficiency_score" db:"efficiency_score"`
	LastAction      string    `json:"last_action" db:"last_action"`
	UpdatedAt       time.Time `json:"updated_at" db:"updated_at"`
}

// IngestPayload is the payload received from the Hardware Service.
type IngestPayload struct {
	SensorID  string                 `json:"sensor_id" binding:"required"`
	Readings  []ParameterReading     `json:"readings" binding:"required"`
	Timestamp time.Time              `json:"timestamp"`
	Metadata  map[string]interface{} `json:"metadata,omitempty"`
}

// ParameterReading is a single measured value for a specific parameter.
type ParameterReading struct {
	ParameterID string  `json:"parameter_id"`
	Value       float64 `json:"value"`
}

// DecisionTableEntry represents a row in the consolidated decision table.
type DecisionTableEntry struct {
	ParameterID string           `json:"parameter_id"`
	Threshold   *Threshold       `json:"threshold,omitempty"`
	Rules       []AutomationRule `json:"rules"`
	LatestValue *float64         `json:"latest_value,omitempty"`
	Status      string           `json:"status"` // "NORMAL", "LOW", "HIGH", "NO_DATA"
}

// AutomationDecision is the action the system should take based on the current value.
type AutomationDecision struct {
	EquipmentID string `json:"equipment_id"`
	Action      string `json:"action"`
	Reason      string `json:"reason"`
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
