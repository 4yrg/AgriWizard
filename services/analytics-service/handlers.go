package main

import (
	"bytes"
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
	"github.com/nats-io/nats.go"
)

// Handler holds shared dependencies.
type Handler struct {
	status      *ServiceStatus
	jwtSecret   string
	hardwareURL string
	weatherURL  string
	js          nats.JetStreamContext
}

// NewHandler creates a new Handler.
func NewHandler(status *ServiceStatus, jwtSecret, hardwareURL, weatherURL string, js nats.JetStreamContext) *Handler {
	return &Handler{status: status, jwtSecret: jwtSecret, hardwareURL: hardwareURL, weatherURL: weatherURL, js: js}
}

// publishNotification publishes a notification message to NATS JetStream.
func (h *Handler) publishNotification(recipient, subject, body string) {
	if h.js == nil {
		return
	}
	msg, _ := json.Marshal(map[string]string{
		"channel":   "email",
		"recipient": recipient,
		"subject":   subject,
		"body":      body,
	})
	if _, err := h.js.Publish("notifications.send", msg); err != nil {
		log.Printf("[WARN] Failed to publish notification: %v", err)
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
	rows, err := h.db().Query(`SELECT id, parameter_id, min_value, max_value, is_enabled FROM analytics.thresholds WHERE is_enabled=true`)
	if err != nil {
		log.Printf("[ERROR] GetDecisionSummary: %v", err)
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "db_error"})
		return
	}
	defer rows.Close()

	var entries []DecisionTableEntry
	for rows.Next() {
		var t Threshold
		if err := rows.Scan(&t.ID, &t.ParameterID, &t.MinValue, &t.MaxValue, &t.IsEnabled); err != nil {
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

	var decisions []AutomationDecision

	for _, reading := range payload.Readings {
		// Fetch the threshold for this parameter
		var t Threshold
		err := h.db().QueryRow(
			`SELECT id, min_value, max_value, is_enabled FROM analytics.thresholds WHERE parameter_id=$1 AND is_enabled=true`,
			reading.ParameterID,
		).Scan(&t.ID, &t.MinValue, &t.MaxValue, &t.IsEnabled)
		if err != nil {
			// No threshold defined — skip
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
			h.updateDailySummary(reading.ParameterID, reading.Value, payload.Timestamp)
			continue
		}

		// Check weather before triggering irrigation-related rules
		scaleFactor := h.getWeatherScaleFactor()

		// Fetch automation rules for this threshold
		rules, _ := h.db().Query(
			`SELECT equipment_id, low_action, high_action FROM analytics.automation_rules WHERE threshold_id=$1`,
			t.ID,
		)
		if rules != nil {
			defer rules.Close()
			for rules.Next() {
				var equipID, lowAction, highAction string
				if rules.Scan(&equipID, &lowAction, &highAction) != nil {
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
			}
		}

		h.updateDailySummary(reading.ParameterID, reading.Value, payload.Timestamp)
	}

	// Notify about threshold breaches and automation actions
	if len(decisions) > 0 {
		var rows string
		for _, d := range decisions {
			rows += fmt.Sprintf("<tr><td>%s</td><td>%s</td><td>%s</td></tr>", d.EquipmentID, d.Action, d.Reason)
		}
		h.publishNotification("farmer@agriwizard.local",
			fmt.Sprintf("Threshold Alert: %d automation(s) triggered", len(decisions)),
			fmt.Sprintf("<h2>Threshold Breach Detected</h2><table border='1' cellpadding='5'><tr><th>Equipment</th><th>Action</th><th>Reason</th></tr>%s</table><p>Automated actions have been dispatched.</p>", rows),
		)
	}

	c.JSON(http.StatusOK, SuccessResponse{
		Message: "ingest processed",
		Data:    gin.H{"decisions_triggered": len(decisions), "decisions": decisions},
	})
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

// ──────────────────────────────────────────────
//  Internal helpers
// ──────────────────────────────────────────────

// updateDailySummary upserts the daily aggregation for a parameter.
func (h *Handler) updateDailySummary(paramID string, value float64, ts time.Time) {
	date := ts.UTC().Truncate(24 * time.Hour)
	_, err := h.db().Exec(`
		INSERT INTO analytics.daily_summaries (parameter_id, avg_value, min_recorded, max_recorded, date)
		VALUES ($1, $2, $2, $2, $3)
		ON CONFLICT (parameter_id, date) DO UPDATE SET
			avg_value    = (analytics.daily_summaries.avg_value + EXCLUDED.avg_value) / 2,
			min_recorded = LEAST(analytics.daily_summaries.min_recorded, EXCLUDED.min_recorded),
			max_recorded = GREATEST(analytics.daily_summaries.max_recorded, EXCLUDED.max_recorded)
	`, paramID, value, date)
	if err != nil {
		log.Printf("[WARN] updateDailySummary: %v", err)
	}
}

// getWeatherScaleFactor calls the Weather service for an irrigation scale factor.
func (h *Handler) getWeatherScaleFactor() float64 {
	if h.weatherURL == "" {
		return 1.0
	}
	resp, err := http.Get(h.weatherURL + "/api/v1/weather/recommendations")
	if err != nil {
		log.Printf("[WARN] getWeatherScaleFactor: %v", err)
		return 1.0
	}
	defer resp.Body.Close()

	var result struct {
		Data struct {
			Scale float64 `json:"scale"`
		} `json:"data"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
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
