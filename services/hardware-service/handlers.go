package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	mqtt "github.com/eclipse/paho.mqtt.golang"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/nats-io/nats.go"
)

// Handler holds shared dependencies for all HTTP handlers.
type Handler struct {
	status       *ServiceStatus
	jwtSecret    string
	analyticsURL string
	js           nats.JetStreamContext
}

// NewHandler creates a new Handler.
func NewHandler(status *ServiceStatus, jwtSecret, analyticsURL string, js nats.JetStreamContext) *Handler {
	return &Handler{status: status, jwtSecret: jwtSecret, analyticsURL: analyticsURL, js: js}
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

func (h *Handler) mqttClient() mqtt.Client {
	return h.status.GetMQTTClient()
}

// ──────────────────────────────────────────────
//  Equipment Handlers
// ──────────────────────────────────────────────

// CreateEquipment godoc
// @Summary      Register a new equipment controller
// @Tags         equipment
// @Accept       json
// @Produce      json
// @Security     BearerAuth
// @Param        body  body      CreateEquipmentRequest  true  "Equipment payload"
// @Success      201   {object}  SuccessResponse
// @Failure      400   {object}  ErrorResponse
// @Router       /api/v1/hardware/equipments [post]
func (h *Handler) CreateEquipment(c *gin.Context) {
	var req CreateEquipmentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "invalid_request", Message: err.Error()})
		return
	}

	id := uuid.New().String()
	mqttTopic := fmt.Sprintf("agriwizard/equipment/%s/command", id)
	ops := StringArray(req.SupportedOperations)

	_, err := h.db().Exec(
		`INSERT INTO hardware.equipments (id, name, operations, mqtt_topic, api_url, current_status)
		 VALUES ($1, $2, $3, $4, $5, $6)`,
		id, req.Name, ops, mqttTopic, req.APIURL, string(StatusOff),
	)
	if err != nil {
		log.Printf("[ERROR] CreateEquipment: %v", err)
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "db_error"})
		return
	}

	// Subscribe to the newly created equipment topic to receive status updates
	if client := h.mqttClient(); client != nil && client.IsConnected() {
		if token := client.Subscribe(mqttTopic+"/status", 1, h.handleEquipmentStatus); token.Wait() && token.Error() != nil {
			log.Printf("[WARN] CreateEquipment: mqtt subscribe failed: %v", token.Error())
		}
	} else {
		log.Printf("[WARN] CreateEquipment: MQTT not connected, skipping subscription for %s", id)
	}

	log.Printf("[INFO] CreateEquipment: registered id=%s name=%s topic=%s", id, req.Name, mqttTopic)
	c.JSON(http.StatusCreated, SuccessResponse{
		Message: "equipment registered",
		Data:    gin.H{"id": id, "mqtt_topic": mqttTopic},
	})
}

// ListEquipments godoc
// @Summary      Retrieve all registered equipment
// @Tags         equipment
// @Produce      json
// @Security     BearerAuth
// @Success      200  {object}  SuccessResponse
// @Router       /api/v1/hardware/equipments [get]
func (h *Handler) ListEquipments(c *gin.Context) {
	rows, err := h.db().Query(`SELECT id, name, operations, mqtt_topic, api_url, current_status, created_at FROM hardware.equipments ORDER BY created_at DESC`)
	if err != nil {
		log.Printf("[ERROR] ListEquipments: %v", err)
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "db_error"})
		return
	}
	defer rows.Close()

	var equipments []Equipment
	for rows.Next() {
		var eq Equipment
		if err := rows.Scan(&eq.ID, &eq.Name, &eq.SupportedOperations, &eq.MQTTTopic, &eq.APIURL, &eq.CurrentStatus, &eq.CreatedAt); err != nil {
			log.Printf("[ERROR] ListEquipments scan: %v", err)
			continue
		}
		equipments = append(equipments, eq)
	}
	if equipments == nil {
		equipments = []Equipment{}
	}
	c.JSON(http.StatusOK, SuccessResponse{Data: equipments})
}

// DispatchControl godoc
// @Summary      Dispatch an operation command to equipment via MQTT
// @Tags         equipment
// @Accept       json
// @Produce      json
// @Security     BearerAuth
// @Param        id    path      string          true  "Equipment ID"
// @Param        body  body      ControlCommand  true  "Command payload"
// @Success      200   {object}  SuccessResponse
// @Failure      400   {object}  ErrorResponse
// @Failure      404   {object}  ErrorResponse
// @Router       /api/v1/hardware/control/{id} [post]
func (h *Handler) DispatchControl(c *gin.Context) {
	equipmentID := c.Param("id")

	var eq Equipment
	err := h.db().QueryRow(
		`SELECT id, name, operations, mqtt_topic, current_status FROM hardware.equipments WHERE id = $1`,
		equipmentID,
	).Scan(&eq.ID, &eq.Name, &eq.SupportedOperations, &eq.MQTTTopic, &eq.CurrentStatus)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, ErrorResponse{Error: "equipment_not_found"})
		return
	}
	if err != nil {
		log.Printf("[ERROR] DispatchControl: db: %v", err)
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "db_error"})
		return
	}

	if eq.CurrentStatus == StatusLocked || eq.CurrentStatus == StatusDisabled {
		c.JSON(http.StatusConflict, ErrorResponse{
			Error:   "equipment_unavailable",
			Message: fmt.Sprintf("equipment is currently %s", eq.CurrentStatus),
		})
		return
	}

	var cmd ControlCommand
	if err := c.ShouldBindJSON(&cmd); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "invalid_request", Message: err.Error()})
		return
	}

	// Validate operation is supported
	supported := false
	for _, op := range eq.SupportedOperations {
		if strings.EqualFold(op, cmd.Operation) {
			supported = true
			break
		}
	}
	if !supported {
		c.JSON(http.StatusBadRequest, ErrorResponse{
			Error:   "unsupported_operation",
			Message: fmt.Sprintf("supported operations: %v", []string(eq.SupportedOperations)),
		})
		return
	}

	// Build and publish MQTT command
	mqttMsg := MQTTCommandMessage{
		EquipmentID: equipmentID,
		Operation:   cmd.Operation,
		Payload:     cmd.Payload,
		IssuedAt:    time.Now().UTC(),
	}
	msgBytes, _ := json.Marshal(mqttMsg)

	if client := h.mqttClient(); client != nil && client.IsConnected() {
		token := client.Publish(eq.MQTTTopic, 1, false, msgBytes)
		token.Wait()
		if token.Error() != nil {
			log.Printf("[ERROR] DispatchControl: mqtt publish: %v", token.Error())
			c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "mqtt_error", Message: token.Error().Error()})
			return
		}
	} else {
		log.Printf("[WARN] DispatchControl: MQTT not connected, command not published via MQTT")
	}

	// Optimistically update status in DB
	newStatus := StatusOn
	if strings.EqualFold(cmd.Operation, "OFF") || strings.EqualFold(cmd.Operation, "TURN_OFF") {
		newStatus = StatusOff
	}
	_, _ = h.db().Exec(`UPDATE hardware.equipments SET current_status=$1 WHERE id=$2`, string(newStatus), equipmentID)

	log.Printf("[INFO] DispatchControl: published cmd=%s to topic=%s", cmd.Operation, eq.MQTTTopic)
	c.JSON(http.StatusOK, SuccessResponse{
		Message: "command dispatched",
		Data:    gin.H{"equipment_id": equipmentID, "operation": cmd.Operation, "mqtt_topic": eq.MQTTTopic},
	})
}

// ──────────────────────────────────────────────
//  Sensor Handlers
// ──────────────────────────────────────────────

// CreateSensor godoc
// @Summary      Provision a new sensor device
// @Tags         sensors
// @Accept       json
// @Produce      json
// @Security     BearerAuth
// @Param        body  body      CreateSensorRequest  true  "Sensor payload"
// @Success      201   {object}  SuccessResponse
// @Failure      400   {object}  ErrorResponse
// @Router       /api/v1/hardware/sensors [post]
func (h *Handler) CreateSensor(c *gin.Context) {
	var req CreateSensorRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "invalid_request", Message: err.Error()})
		return
	}

	if req.UpdateFrequency == 0 {
		req.UpdateFrequency = 60
	}

	id := uuid.New().String()
	mqttTopic := fmt.Sprintf("agriwizard/sensor/%s/telemetry", id)
	paramIDs := StringArray(req.ParameterIDs)

	_, err := h.db().Exec(
		`INSERT INTO hardware.sensors (id, name, parameter_ids, mqtt_topic, api_url, update_frequency)
		 VALUES ($1, $2, $3, $4, $5, $6)`,
		id, req.Name, paramIDs, mqttTopic, req.APIURL, req.UpdateFrequency,
	)
	if err != nil {
		log.Printf("[ERROR] CreateSensor: %v", err)
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "db_error"})
		return
	}

	// Subscribe to telemetry topic for incoming data
	if client := h.mqttClient(); client != nil && client.IsConnected() {
		client.Subscribe(mqttTopic, 1, h.handleTelemetry)
	} else {
		log.Printf("[WARN] CreateSensor: MQTT not connected, skipping subscription for %s", id)
	}

	log.Printf("[INFO] CreateSensor: provisioned id=%s name=%s topic=%s", id, req.Name, mqttTopic)
	c.JSON(http.StatusCreated, SuccessResponse{
		Message: "sensor provisioned",
		Data:    gin.H{"id": id, "mqtt_topic": mqttTopic},
	})
}

// ListSensors godoc
// @Summary      Get all sensors including associated parameters
// @Tags         sensors
// @Produce      json
// @Security     BearerAuth
// @Success      200  {object}  SuccessResponse
// @Router       /api/v1/hardware/sensors [get]
func (h *Handler) ListSensors(c *gin.Context) {
	rows, err := h.db().Query(`SELECT id, name, parameter_ids, mqtt_topic, api_url, update_frequency, created_at FROM hardware.sensors ORDER BY created_at DESC`)
	if err != nil {
		log.Printf("[ERROR] ListSensors: %v", err)
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "db_error"})
		return
	}
	defer rows.Close()

	type SensorWithParams struct {
		Sensor
		Parameters []Parameter `json:"parameters"`
	}

	var sensors []SensorWithParams
	for rows.Next() {
		var s Sensor
		if err := rows.Scan(&s.ID, &s.Name, &s.ParameterIDs, &s.MQTTTopic, &s.APIURL, &s.UpdateFrequency, &s.CreatedAt); err != nil {
			log.Printf("[ERROR] ListSensors scan: %v", err)
			continue
		}
		// Fetch parameter details
		var params []Parameter
		for _, pid := range s.ParameterIDs {
			var p Parameter
			if err := h.db().QueryRow(`SELECT id, unit, description FROM hardware.parameters WHERE id=$1`, pid).
				Scan(&p.ID, &p.Unit, &p.Description); err == nil {
				params = append(params, p)
			}
		}
		if params == nil {
			params = []Parameter{}
		}
		sensors = append(sensors, SensorWithParams{Sensor: s, Parameters: params})
	}
	if sensors == nil {
		sensors = []SensorWithParams{}
	}
	c.JSON(http.StatusOK, SuccessResponse{Data: sensors})
}

// ──────────────────────────────────────────────
//  Parameter Handlers
// ──────────────────────────────────────────────

// CreateParameter godoc
// @Summary      Define a new parameter/metric type
// @Tags         parameters
// @Accept       json
// @Produce      json
// @Security     BearerAuth
// @Param        body  body      CreateParameterRequest  true  "Parameter payload"
// @Success      201   {object}  SuccessResponse
// @Failure      400   {object}  ErrorResponse
// @Router       /api/v1/hardware/parameters [post]
func (h *Handler) CreateParameter(c *gin.Context) {
	var req CreateParameterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "invalid_request", Message: err.Error()})
		return
	}

	_, err := h.db().Exec(
		`INSERT INTO hardware.parameters (id, unit, description) VALUES ($1, $2, $3) ON CONFLICT (id) DO UPDATE SET unit=$2, description=$3`,
		req.ID, req.Unit, req.Description,
	)
	if err != nil {
		log.Printf("[ERROR] CreateParameter: %v", err)
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "db_error"})
		return
	}

	c.JSON(http.StatusCreated, SuccessResponse{Message: "parameter defined", Data: gin.H{"id": req.ID}})
}

// ListParameters godoc
// @Summary      List all defined parameter types
// @Tags         parameters
// @Produce      json
// @Security     BearerAuth
// @Success      200  {object}  SuccessResponse
// @Router       /api/v1/hardware/parameters [get]
func (h *Handler) ListParameters(c *gin.Context) {
	rows, err := h.db().Query(`SELECT id, unit, description, created_at FROM hardware.parameters ORDER BY id`)
	if err != nil {
		log.Printf("[ERROR] ListParameters: %v", err)
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "db_error"})
		return
	}
	defer rows.Close()

	var params []Parameter
	for rows.Next() {
		var p Parameter
		if err := rows.Scan(&p.ID, &p.Unit, &p.Description, &p.CreatedAt); err == nil {
			params = append(params, p)
		}
	}
	if params == nil {
		params = []Parameter{}
	}
	c.JSON(http.StatusOK, SuccessResponse{Data: params})
}

// ──────────────────────────────────────────────
//  Telemetry Handlers
// ──────────────────────────────────────────────

// IngestTelemetry godoc
// @Summary      Ingest raw telemetry data via REST
// @Tags         telemetry
// @Accept       json
// @Produce      json
// @Security     BearerAuth
// @Param        body  body      TelemetryPayload  true  "Telemetry payload"
// @Success      201   {object}  SuccessResponse
// @Router       /api/v1/hardware/telemetry [post]
func (h *Handler) IngestTelemetry(c *gin.Context) {
	var payload TelemetryPayload
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "invalid_request", Message: err.Error()})
		return
	}
	if payload.Timestamp.IsZero() {
		payload.Timestamp = time.Now().UTC()
	}
	if err := h.storeTelemetry(payload); err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "storage_error"})
		return
	}
	c.JSON(http.StatusCreated, SuccessResponse{Message: "telemetry ingested"})
}

// ──────────────────────────────────────────────
//  MQTT Callbacks
// ──────────────────────────────────────────────

// handleTelemetry is the MQTT message handler for sensor telemetry topics.
func (h *Handler) handleTelemetry(_ mqtt.Client, msg mqtt.Message) {
	var payload TelemetryPayload
	if err := json.Unmarshal(msg.Payload(), &payload); err != nil {
		log.Printf("[WARN] handleTelemetry: unmarshal error: %v", err)
		return
	}
	if payload.Timestamp.IsZero() {
		payload.Timestamp = time.Now().UTC()
	}
	if err := h.storeTelemetry(payload); err != nil {
		log.Printf("[ERROR] handleTelemetry: store error: %v", err)
	}
}

// handleEquipmentStatus handles status update messages from equipment devices.
func (h *Handler) handleEquipmentStatus(_ mqtt.Client, msg mqtt.Message) {
	var eqStatus struct {
		EquipmentID string `json:"equipment_id"`
		Status      string `json:"status"`
	}
	if err := json.Unmarshal(msg.Payload(), &eqStatus); err != nil {
		return
	}
	if _, err := h.db().Exec(
		`UPDATE hardware.equipments SET current_status=$1 WHERE id=$2`,
		eqStatus.Status, eqStatus.EquipmentID,
	); err != nil {
		log.Printf("[ERROR] handleEquipmentStatus: %v", err)
		return
	}

	// Notify on critical status changes
	if strings.EqualFold(eqStatus.Status, "LOCKED") || strings.EqualFold(eqStatus.Status, "DISABLED") {
		h.publishNotification("farmer@agriwizard.local",
			fmt.Sprintf("Equipment %s is now %s", eqStatus.EquipmentID, eqStatus.Status),
			fmt.Sprintf("<h2>Equipment Status Change</h2><p>Equipment <b>%s</b> has changed to <b>%s</b>.</p><p>This device will not accept commands until its status is restored.</p>", eqStatus.EquipmentID, eqStatus.Status),
		)
	}
}

// storeTelemetry persists telemetry data and forwards it to the analytics service.
func (h *Handler) storeTelemetry(payload TelemetryPayload) error {
	for _, r := range payload.Readings {
		_, err := h.db().Exec(
			`INSERT INTO hardware.raw_sensor_data (sensor_id, parameter_id, value, timestamp) VALUES ($1, $2, $3, $4)`,
			payload.SensorID, r.ParameterID, r.Value, payload.Timestamp,
		)
		if err != nil {
			log.Printf("[ERROR] storeTelemetry: insert: %v", err)
			return err
		}
		log.Printf("[INFO] storeTelemetry: stored sensor=%s param=%s value=%.4f", payload.SensorID, r.ParameterID, r.Value)
	}
	// Forward to AgriLogic analytics service for threshold evaluation
	go h.forwardToAnalytics(payload)
	return nil
}

// forwardToAnalytics sends telemetry to the AgriLogic ingest endpoint.
func (h *Handler) forwardToAnalytics(payload TelemetryPayload) {
	if h.analyticsURL == "" {
		return
	}
	body, _ := json.Marshal(payload)
	url := h.analyticsURL + "/api/v1/analytics/ingest"
	resp, err := makeInternalRequest("POST", url, body)
	if err != nil {
		log.Printf("[WARN] forwardToAnalytics: %v", err)
		return
	}
	defer resp.Body.Close()
	log.Printf("[INFO] forwardToAnalytics: status=%d", resp.StatusCode)
}

// ──────────────────────────────────────────────
//  JWT Middleware
// ──────────────────────────────────────────────

// JWTAuthMiddleware validates Bearer tokens for protected routes.
func (h *Handler) JWTAuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
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
