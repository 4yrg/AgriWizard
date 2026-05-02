package main

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

// Handler holds shared dependencies.
type Handler struct {
	status                  *ServiceStatus
	jwtSecret               string
	hardwareURL             string
	weatherURL              string
	sbNotificationPublisher *AzureServiceBusNotificationPublisher
}

// NewHandler creates a new Handler.
func NewHandler(status *ServiceStatus, jwtSecret, hardwareURL, weatherURL string, sbNotificationPublisher *AzureServiceBusNotificationPublisher) *Handler {
	return &Handler{
		status:                  status,
		jwtSecret:               jwtSecret,
		hardwareURL:             hardwareURL,
		weatherURL:              weatherURL,
		sbNotificationPublisher: sbNotificationPublisher,
	}
}

// requireDB is a middleware that checks if the database is ready.
func (h *Handler) requireDB() gin.HandlerFunc {
	return func(c *gin.Context) {
		if !h.status.IsReady() {
			c.JSON(http.StatusServiceUnavailable, ErrorResponse{
				Error:   "service_unavailable",
				Message: "database connection not ready, please try again later",
			})
			c.Abort()
			return
		}
		c.Next()
	}
}

func (h *Handler) db() *sql.DB {
	return h.status.GetDB()
}

// ──────────────────────────────────────────────
//  Threshold Handlers
// ──────────────────────────────────────────────

// UpsertThreshold godoc
// @Summary      Create or update a threshold range for a parameter
// @Tags         thresholds
// @Accept       json
// @Produce      json
// @Security     BearerAuth
// @Param        body  body      UpsertThresholdRequest  true  "Threshold payload"
// @Success      200   {object}  SuccessResponse
// @Failure      400   {object}  ErrorResponse
// @Router       /api/v1/analytics/thresholds [post]
func (h *Handler) UpsertThreshold(c *gin.Context) {
	var req UpsertThresholdRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "invalid_request", Message: err.Error()})
		return
	}

	if req.MaxValue <= req.MinValue {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "invalid_range", Message: "max_value must be greater than min_value"})
		return
	}

	enabled := true
	if req.IsEnabled != nil {
		enabled = *req.IsEnabled
	}

	// Upsert: update if parameter_id exists, else insert
	var existingID string
	err := h.db().QueryRow(`SELECT id FROM analytics.thresholds WHERE parameter_id=$1`, req.ParameterID).Scan(&existingID)

	var thresholdID string
	if err == sql.ErrNoRows {
		thresholdID = uuid.New().String()
		_, err = h.db().Exec(
			`INSERT INTO analytics.thresholds (id, parameter_id, min_value, max_value, is_enabled) VALUES ($1, $2, $3, $4, $5)`,
			thresholdID, req.ParameterID, req.MinValue, req.MaxValue, enabled,
		)
	} else {
		thresholdID = existingID
		_, err = h.db().Exec(
			`UPDATE analytics.thresholds SET min_value=$1, max_value=$2, is_enabled=$3, updated_at=NOW() WHERE id=$4`,
			req.MinValue, req.MaxValue, enabled, existingID,
		)
	}

	if err != nil {
		log.Printf("[ERROR] UpsertThreshold: %v", err)
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "db_error"})
		return
	}

	log.Printf("[INFO] UpsertThreshold: id=%s param=%s min=%.2f max=%.2f", thresholdID, req.ParameterID, req.MinValue, req.MaxValue)
	c.JSON(http.StatusOK, SuccessResponse{
		Message: "threshold saved",
		Data:    gin.H{"id": thresholdID, "parameter_id": req.ParameterID},
	})
}

// GetThreshold godoc
// @Summary      Fetch threshold bounds for a specific parameter
// @Tags         thresholds
// @Produce      json
// @Security     BearerAuth
// @Param        parameterId  path      string  true  "Parameter ID"
// @Success      200          {object}  SuccessResponse
// @Failure      404          {object}  ErrorResponse
// @Router       /api/v1/analytics/thresholds/{parameterId} [get]
func (h *Handler) GetThreshold(c *gin.Context) {
	paramID := c.Param("parameterId")
	var t Threshold
	err := h.db().QueryRow(
		`SELECT id, parameter_id, min_value, max_value, is_enabled, created_at, updated_at FROM analytics.thresholds WHERE parameter_id=$1`,
		paramID,
	).Scan(&t.ID, &t.ParameterID, &t.MinValue, &t.MaxValue, &t.IsEnabled, &t.CreatedAt, &t.UpdatedAt)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, ErrorResponse{Error: "threshold_not_found"})
		return
	}
	if err != nil {
		log.Printf("[ERROR] GetThreshold: %v", err)
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "db_error"})
		return
	}
	c.JSON(http.StatusOK, SuccessResponse{Data: t})
}

// ──────────────────────────────────────────────
//  Automation Rule Handlers
// ──────────────────────────────────────────────

// CreateRule godoc
// @Summary      Create an automation rule linking a threshold to equipment
// @Tags         rules
// @Accept       json
// @Produce      json
// @Security     BearerAuth
// @Param        body  body      CreateRuleRequest  true  "Rule payload"
// @Success      201   {object}  SuccessResponse
// @Failure      400   {object}  ErrorResponse
// @Router       /api/v1/analytics/rules [post]
func (h *Handler) CreateRule(c *gin.Context) {
	var req CreateRuleRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "invalid_request", Message: err.Error()})
		return
	}

	// Verify threshold exists
	var thresholdID string
	if err := h.db().QueryRow(`SELECT id FROM analytics.thresholds WHERE id=$1`, req.ThresholdID).Scan(&thresholdID); err == sql.ErrNoRows {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "threshold_not_found", Message: "referenced threshold does not exist"})
		return
	}

	ruleID := uuid.New().String()
	_, err := h.db().Exec(
		`INSERT INTO analytics.automation_rules (id, threshold_id, equipment_id, low_action, high_action) VALUES ($1, $2, $3, $4, $5)`,
		ruleID, req.ThresholdID, req.EquipmentID, req.LowAction, req.HighAction,
	)
	if err != nil {
		log.Printf("[ERROR] CreateRule: %v", err)
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "db_error"})
		return
	}

	log.Printf("[INFO] CreateRule: id=%s threshold=%s equipment=%s", ruleID, req.ThresholdID, req.EquipmentID)
	c.JSON(http.StatusCreated, SuccessResponse{Message: "rule created", Data: gin.H{"id": ruleID}})
}

// GetRulesForParameter godoc
// @Summary      Retrieve automation rules linked to a parameter's threshold
// @Tags         rules
// @Produce      json
// @Security     BearerAuth
// @Param        parameterId  path      string  true  "Parameter ID"
// @Success      200          {object}  SuccessResponse
// @Failure      404          {object}  ErrorResponse
// @Router       /api/v1/analytics/rules/{parameterId} [get]
func (h *Handler) GetRulesForParameter(c *gin.Context) {
	paramID := c.Param("parameterId")

	rows, err := h.db().Query(`
		SELECT r.id, r.threshold_id, r.equipment_id, r.low_action, r.high_action, r.created_at
		FROM analytics.automation_rules r
		JOIN analytics.thresholds t ON t.id = r.threshold_id
		WHERE t.parameter_id = $1
	`, paramID)
	if err != nil {
		log.Printf("[ERROR] GetRulesForParameter: %v", err)
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "db_error"})
		return
	}
	defer rows.Close()

	var rules []AutomationRule
	for rows.Next() {
		var r AutomationRule
		if err := rows.Scan(&r.ID, &r.ThresholdID, &r.EquipmentID, &r.LowAction, &r.HighAction, &r.CreatedAt); err == nil {
			rules = append(rules, r)
		}
	}
	if rules == nil {
		rules = []AutomationRule{}
	}
	c.JSON(http.StatusOK, SuccessResponse{Data: rules})
}

// ──────────────────────────────────────────────
//  Decision Summary
// ──────────────────────────────────────────────

// GetDecisionSummary godoc
// @Summary      Retrieve the full decision table for all parameters
// @Tags         analytics
// @Produce      json
// @Security     BearerAuth
// @Success      200  {object}  SuccessResponse
// @Router       /api/v1/analytics/decisions/summary [get]
func (h *Handler) GetDecisionSummary(c *gin.Context) {
	// Fetch all thresholds
	rows, err := h.db().Query(`SELECT id, parameter_id, min_value, max_value, is_enabled, created_at, updated_at FROM analytics.thresholds WHERE is_enabled=true`)
	if err != nil {
		log.Printf("[ERROR] GetDecisionSummary: %v", err)
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "db_error"})
		return
	}
	defer rows.Close()

	var entries []DecisionTableEntry
	for rows.Next() {
		var t Threshold
		if err := rows.Scan(&t.ID, &t.ParameterID, &t.MinValue, &t.MaxValue, &t.IsEnabled, &t.CreatedAt, &t.UpdatedAt); err != nil {
			continue
		}

		entry := DecisionTableEntry{
			ParameterID: t.ParameterID,
			Threshold:   &t,
			Status:      "NO_DATA",
		}

		// Get latest sensor value for this parameter
		var latestVal float64
		err := h.db().QueryRow(`
			SELECT value FROM hardware.raw_sensor_data WHERE parameter_id=$1 ORDER BY timestamp DESC LIMIT 1
		`, t.ParameterID).Scan(&latestVal)
		if err == nil {
			entry.LatestValue = &latestVal
			switch {
			case latestVal < t.MinValue:
				entry.Status = "LOW"
			case latestVal > t.MaxValue:
				entry.Status = "HIGH"
			default:
				entry.Status = "NORMAL"
			}
		}

		// Get linked automation rules
		ruleRows, _ := h.db().Query(`
			SELECT id, threshold_id, equipment_id, low_action, high_action FROM analytics.automation_rules WHERE threshold_id=$1
		`, t.ID)
		if ruleRows != nil {
			defer ruleRows.Close()
			for ruleRows.Next() {
				var r AutomationRule
				if ruleRows.Scan(&r.ID, &r.ThresholdID, &r.EquipmentID, &r.LowAction, &r.HighAction) == nil {
					entry.Rules = append(entry.Rules, r)
				}
			}
		}
		if entry.Rules == nil {
			entry.Rules = []AutomationRule{}
		}

		entries = append(entries, entry)
	}
	if entries == nil {
		entries = []DecisionTableEntry{}
	}
	c.JSON(http.StatusOK, SuccessResponse{Data: entries})
}

// ──────────────────────────────────────────────
//  Ingest Handler
// ──────────────────────────────────────────────

// Ingest godoc
// @Summary      Ingest raw telemetry and apply threshold automation logic
// @Tags         analytics
// @Accept       json
// @Produce      json
// @Security     BearerAuth
// @Param        body  body      IngestPayload  true  "Telemetry payload"
// @Success      200   {object}  SuccessResponse
// @Failure      400   {object}  ErrorResponse
// @Router       /api/v1/analytics/ingest [post]
func (h *Handler) Ingest(c *gin.Context) {
	var payload IngestPayload
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "invalid_request", Message: err.Error()})
		return
	}
	if payload.Timestamp.IsZero() {
		payload.Timestamp = time.Now().UTC()
	}

	decisions, err := h.ProcessIngest(payload)
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "processing_error", Message: err.Error()})
		return
	}

	c.JSON(http.StatusOK, SuccessResponse{
		Message: "ingest processed",
		Data:    gin.H{"decisions_triggered": len(decisions), "decisions": decisions},
	})
}

// ProcessIngest processes telemetry data and applies threshold automation logic.
// This is used by both the REST API and Service Bus consumer.
func (h *Handler) ProcessIngest(payload IngestPayload) ([]AutomationDecision, error) {
	var decisions []AutomationDecision

	for _, reading := range payload.Readings {
		// Store telemetry to database for decision summary to show current values
		if err := h.storeTelemetry(payload.SensorID, reading.ParameterID, reading.Value, payload.Timestamp); err != nil {
			log.Printf("[WARN] ProcessIngest: failed to store telemetry: %v", err)
		}

		// Always update daily summary regardless of threshold existence
		h.updateDailySummary(reading.ParameterID, reading.Value, payload.Timestamp)

		// Fetch the threshold for this parameter to see if automation is needed
		var t Threshold
		err := h.db().QueryRow(
			`SELECT id, min_value, max_value, is_enabled FROM analytics.thresholds WHERE parameter_id=$1 AND is_enabled=true`,
			reading.ParameterID,
		).Scan(&t.ID, &t.MinValue, &t.MaxValue, &t.IsEnabled)

		if err != nil {
			// No threshold defined or disabled — skip automation logic but data was summarized
			log.Printf("[DEBUG] ProcessIngest: no active threshold for %s", reading.ParameterID)
			continue
		}

		// Determine if threshold is breached and which action applies
		var actionToTake string
		var reason string
		if reading.Value < t.MinValue {
			actionToTake = "low"
			reason = fmt.Sprintf("value %.2f is below min %.2f", reading.Value, t.MinValue)
		} else if reading.Value > t.MaxValue {
			actionToTake = "high"
			reason = fmt.Sprintf("value %.2f is above max %.2f", reading.Value, t.MaxValue)
		}

		if actionToTake == "" {
			log.Printf("[INFO] Ingest: param=%s value=%.2f is NORMAL", reading.ParameterID, reading.Value)
			continue
		}

		// Check weather before triggering irrigation-related rules
		scaleFactor := h.getWeatherScaleFactor()

		// Fetch automation rules for this threshold
		rules, err := h.db().Query(
			`SELECT equipment_id, low_action, high_action FROM analytics.automation_rules WHERE threshold_id=$1`,
			t.ID,
		)
		if err == nil && rules != nil {
			for rules.Next() {
				var equipID, lowAction, highAction string
				if err := rules.Scan(&equipID, &lowAction, &highAction); err != nil {
					continue
				}
				action := lowAction
				if actionToTake == "high" {
					action = highAction
				}
				decisions = append(decisions, AutomationDecision{
					EquipmentID: equipID,
					Action:      action,
					Reason:      fmt.Sprintf("%s [scale=%.2f]", reason, scaleFactor),
				})
				// Dispatch command to hardware service
				go h.dispatchHardwareCommand(equipID, action)
				// Publish notification for the event
				go h.publishAutomationNotification(payload.SensorID, reading.ParameterID, equipID, reading.Value, action, reason, scaleFactor)
			}
			rules.Close() // Close immediately to avoid cursor leak
		}
	}

	return decisions, nil
}

// GetDailySummaries godoc
// @Summary      Retrieve daily aggregated summaries for all parameters
// @Tags         analytics
// @Produce      json
// @Security     BearerAuth
// @Param        date  query  string  false  "Date in YYYY-MM-DD format (defaults to today)"
// @Success      200   {object}  SuccessResponse
// @Router       /api/v1/analytics/summaries [get]
func (h *Handler) GetDailySummaries(c *gin.Context) {
	dateStr := c.Query("date")
	var date time.Time
	if dateStr == "" {
		date = time.Now().UTC().Truncate(24 * time.Hour)
	} else {
		var err error
		date, err = time.Parse("2006-01-02", dateStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, ErrorResponse{Error: "invalid_date"})
			return
		}
	}

	rows, err := h.db().Query(
		`SELECT id, parameter_id, avg_value, min_recorded, max_recorded, date FROM analytics.daily_summaries WHERE date=$1`,
		date,
	)
	if err != nil {
		log.Printf("[ERROR] GetDailySummaries: %v", err)
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "db_error"})
		return
	}
	defer rows.Close()

	var summaries []DailySummary
	for rows.Next() {
		var s DailySummary
		if err := rows.Scan(&s.ID, &s.ParameterID, &s.AvgValue, &s.MinRecorded, &s.MaxRecorded, &s.Date); err == nil {
			summaries = append(summaries, s)
		}
	}
	if summaries == nil {
		summaries = []DailySummary{}
	}
	c.JSON(http.StatusOK, SuccessResponse{Data: summaries})
}

// GetEquipmentAnalytics godoc
// @Summary      Retrieve analytics for all equipment
// @Tags         analytics
// @Produce      json
// @Security     BearerAuth
// @Param        date  query  string  false  "Date in YYYY-MM-DD format (defaults to today)"
// @Success      200   {object}  SuccessResponse
// @Router       /api/v1/analytics/equipment-analytics [get]
func (h *Handler) GetEquipmentAnalytics(c *gin.Context) {
	dateStr := c.Query("date")
	var date time.Time
	if dateStr == "" {
		date = time.Now().UTC().Truncate(24 * time.Hour)
	} else {
		var err error
		date, err = time.Parse("2006-01-02", dateStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, ErrorResponse{Error: "invalid_date"})
			return
		}
	}

	rows, err := h.db().Query(
		`SELECT id, equipment_id, usage_count, efficiency_score, last_action, date, updated_at FROM analytics.equipment_analysis WHERE date=$1`,
		date,
	)
	if err != nil {
		log.Printf("[ERROR] GetEquipmentAnalytics: %v", err)
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "db_error"})
		return
	}
	defer rows.Close()

	var analytics []EquipmentAnalysis
	for rows.Next() {
		var a EquipmentAnalysis
		if err := rows.Scan(&a.ID, &a.EquipmentID, &a.UsageCount, &a.EfficiencyScore, &a.LastAction, &a.Date, &a.UpdatedAt); err == nil {
			analytics = append(analytics, a)
		}
	}
	if analytics == nil {
		analytics = []EquipmentAnalysis{}
	}
	c.JSON(http.StatusOK, SuccessResponse{Data: analytics})
}

// ──────────────────────────────────────────────
//  Internal helpers
// ──────────────────────────────────────────────

// updateDailySummary upserts the daily aggregation for a parameter.
func (h *Handler) updateDailySummary(paramID string, value float64, ts time.Time) {
	date := ts.UTC().Truncate(24 * time.Hour)
	_, err := h.db().Exec(`
		INSERT INTO analytics.daily_summaries (parameter_id, avg_value, min_recorded, max_recorded, reading_count, date)
		VALUES ($1, $2, $2, $2, 1, $3)
		ON CONFLICT (parameter_id, date) DO UPDATE SET
			avg_value    = (analytics.daily_summaries.avg_value * analytics.daily_summaries.reading_count + EXCLUDED.avg_value) / (analytics.daily_summaries.reading_count + 1),
			min_recorded = LEAST(analytics.daily_summaries.min_recorded, EXCLUDED.min_recorded),
			max_recorded = GREATEST(analytics.daily_summaries.max_recorded, EXCLUDED.max_recorded),
			reading_count = analytics.daily_summaries.reading_count + 1
	`, paramID, value, date)
	if err != nil {
		log.Printf("[WARN] updateDailySummary: %v", err)
	}
}

// storeTelemetry stores raw sensor data to the hardware schema.
// This enables the decision summary to show current values.
func (h *Handler) storeTelemetry(sensorID, parameterID string, value float64, ts time.Time) error {
	if ts.IsZero() {
		ts = time.Now().UTC()
	}
	_, err := h.db().Exec(`
		INSERT INTO hardware.raw_sensor_data (sensor_id, parameter_id, value, timestamp)
		VALUES ($1, $2, $3, $4)
	`, sensorID, parameterID, value, ts)
	if err != nil {
		return err
	}
	log.Printf("[DEBUG] storeTelemetry: stored sensor=%s param=%s value=%.2f", sensorID, parameterID, value)
	return nil
}

// getWeatherScaleFactor calls the Weather service for an irrigation scale factor.
func (h *Handler) getWeatherScaleFactor() float64 {
	if h.weatherURL == "" {
		return 1.0
	}
	req, err := http.NewRequest("GET", h.weatherURL+"/api/v1/weather/recommendations", nil)
	if err != nil {
		log.Printf("[WARN] getWeatherScaleFactor: request build failed: %v", err)
		return 1.0
	}
	req.Header.Set("X-Internal-Service", "analytics-service")

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("[WARN] getWeatherScaleFactor: %v", err)
		return 1.0
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		log.Printf("[WARN] getWeatherScaleFactor: weather returned status=%d", resp.StatusCode)
		return 1.0
	}

	var result struct {
		Data struct {
			Scale float64 `json:"scale"`
		} `json:"data"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		log.Printf("[WARN] getWeatherScaleFactor: decode failed: %v", err)
		return 1.0
	}
	return result.Data.Scale
}

// dispatchHardwareCommand sends a control command to the Hardware Service.
func (h *Handler) dispatchHardwareCommand(equipmentID, action string) {
	if h.hardwareURL == "" {
		log.Printf("[INFO] dispatchHardwareCommand: no hardware URL set, skipping")
		return
	}
	payload := map[string]string{"operation": action}
	body, _ := json.Marshal(payload)
	url := fmt.Sprintf("%s/api/v1/hardware/control/%s", h.hardwareURL, equipmentID)

	req, err := http.NewRequest("POST", url, bytes.NewReader(body))
	if err != nil {
		log.Printf("[ERROR] dispatchHardwareCommand: %v", err)
		return
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Internal-Service", "analytics-service")

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("[WARN] dispatchHardwareCommand: %v", err)
		return
	}
	defer resp.Body.Close()
	log.Printf("[INFO] dispatchHardwareCommand: equipment=%s action=%s status=%d", equipmentID, action, resp.StatusCode)

	if resp.StatusCode == http.StatusOK || resp.StatusCode == http.StatusNoContent {
		h.updateEquipmentUsage(equipmentID, action)
	}
}

// updateEquipmentUsage increments the usage count for an equipment.
func (h *Handler) updateEquipmentUsage(equipmentID, action string) {
	date := time.Now().UTC().Truncate(24 * time.Hour)
	id := uuid.New().String()
	_, err := h.db().Exec(`
		INSERT INTO analytics.equipment_analysis (id, equipment_id, date, usage_count, last_action, updated_at)
		VALUES ($1, $2, $3, 1, $4, NOW())
		ON CONFLICT (equipment_id, date) DO UPDATE SET
			usage_count = analytics.equipment_analysis.usage_count + 1,
			last_action = EXCLUDED.last_action,
			updated_at  = NOW()
	`, id, equipmentID, date, action)
	if err != nil {
		log.Printf("[WARN] updateEquipmentUsage: %v", err)
	}
}

func (h *Handler) publishAutomationNotification(sensorID, parameterID, equipmentID string, value float64, action, reason string, scaleFactor float64) {
	if h.sbNotificationPublisher == nil || !h.sbNotificationPublisher.IsConnected() {
		return
	}

	recipient := getServiceBusNotificationRecipient()
	if recipient == "" {
		log.Println("[WARN] publishAutomationNotification: notification recipient not configured")
		return
	}

	req := NotificationRequest{
		Channel:   "email",
		Recipient: recipient,
		Subject:   fmt.Sprintf("Automation alert: %s action triggered", strings.ToUpper(action)),
		Body: fmt.Sprintf(
			"Sensor %s triggered parameter %s for equipment %s. Value: %.2f. Action: %s. Reason: %s. Scale factor: %.2f.",
			sensorID, parameterID, equipmentID, value, action, reason, scaleFactor,
		),
		Metadata: map[string]string{
			"sensor_id":    sensorID,
			"parameter_id": parameterID,
			"equipment_id": equipmentID,
			"action":       action,
			"value":        fmt.Sprintf("%.2f", value),
			"reason":       reason,
			"scale_factor": fmt.Sprintf("%.2f", scaleFactor),
		},
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := h.sbNotificationPublisher.PublishNotification(ctx, req); err != nil {
		log.Printf("[WARN] Failed to publish automation notification: %v", err)
	}
}

// JWTAuthMiddleware validates Bearer tokens.
func (h *Handler) JWTAuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Allow internal service calls without JWT
		if c.GetHeader("X-Internal-Service") != "" {
			c.Next()
			return
		}
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
			c.AbortWithStatusJSON(http.StatusUnauthorized, ErrorResponse{Error: "missing_token"})
			return
		}
		tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
		token, err := jwt.Parse(tokenStr, func(t *jwt.Token) (interface{}, error) {
			if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, jwt.ErrSignatureInvalid
			}
			return []byte(h.jwtSecret), nil
		})
		if err != nil || !token.Valid {
			c.AbortWithStatusJSON(http.StatusUnauthorized, ErrorResponse{Error: "invalid_token"})
			return
		}
		claims, _ := token.Claims.(jwt.MapClaims)
		c.Set("user_id", claims["user_id"])
		c.Set("role", claims["role"])
		c.Next()
	}
}
