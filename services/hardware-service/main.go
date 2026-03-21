package main

import (
	"bytes"
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	mqtt "github.com/eclipse/paho.mqtt.golang"
	"github.com/gin-gonic/gin"
	_ "github.com/lib/pq"
)

func main() {
	dbHost := getEnv("DB_HOST", "localhost")
	dbPort := getEnv("DB_PORT", "5432")
	dbUser := getEnv("DB_USER", "agriwizard")
	dbPass := getEnv("DB_PASSWORD", "agriwizard_secret")
	dbName := getEnv("DB_NAME", "agriwizard")
	mqttBroker := getEnv("MQTT_BROKER", "tcp://localhost:1883")
	mqttUsername := getEnv("MQTT_USERNAME", "")
	mqttPassword := getEnv("MQTT_PASSWORD", "")
	jwtSecret := getEnv("JWT_SECRET", "super-secret-jwt-key-change-in-production")
	analyticsURL := getEnv("ANALYTICS_SERVICE_URL", "http://analytics-service:8083")
	port := getEnv("PORT", "8082")

	// --- Database ---
	dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		dbHost, dbPort, dbUser, dbPass, dbName)
	db, err := connectDB(dsn)
	if err != nil {
		log.Fatalf("[FATAL] DB connect: %v", err)
	}
	defer db.Close()

	if err := runMigrations(db); err != nil {
		log.Fatalf("[FATAL] Migrations: %v", err)
	}

	// --- MQTT ---
	mqttClient := connectMQTT(mqttBroker, mqttUsername, mqttPassword)

	// --- Restore MQTT subscriptions for existing sensors/equipment ---
	restoreSubscriptions(db, mqttClient)

	// --- Router ---
	if getEnv("GIN_MODE", "debug") == "release" {
		gin.SetMode(gin.ReleaseMode)
	}

	h := NewHandler(db, mqttClient, jwtSecret, analyticsURL)
	r := gin.New()
	r.Use(gin.Logger(), gin.Recovery())

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "hardware-service"})
	})

	api := r.Group("/api/v1/hardware")
	api.Use(h.JWTAuthMiddleware())
	{
		// Equipment
		api.POST("/equipments", h.CreateEquipment)
		api.GET("/equipments", h.ListEquipments)
		api.POST("/control/:id", h.DispatchControl)

		// Sensors
		api.POST("/sensors", h.CreateSensor)
		api.GET("/sensors", h.ListSensors)

		// Parameters
		api.POST("/parameters", h.CreateParameter)
		api.GET("/parameters", h.ListParameters)

		// Telemetry (REST ingestion fallback)
		api.POST("/telemetry", h.IngestTelemetry)
	}

	log.Printf("[INFO] Hardware Service starting on :%s", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatalf("[FATAL] Server: %v", err)
	}
}

func connectDB(dsn string) (*sql.DB, error) {
	var db *sql.DB
	var err error
	for i := 0; i < 10; i++ {
		db, err = sql.Open("postgres", dsn)
		if err == nil {
			if pingErr := db.Ping(); pingErr == nil {
				log.Println("[INFO] Database connected")
				db.SetMaxOpenConns(25)
				db.SetMaxIdleConns(5)
				db.SetConnMaxLifetime(5 * time.Minute)
				return db, nil
			}
		}
		log.Printf("[WARN] DB attempt %d/10, retrying...", i+1)
		time.Sleep(3 * time.Second)
	}
	return nil, fmt.Errorf("db connect failed: %w", err)
}

func connectMQTT(broker, username, password string) mqtt.Client {
	opts := mqtt.NewClientOptions().
		AddBroker(broker).
		SetClientID("agriwizard-hardware-service").
		SetCleanSession(false).
		SetAutoReconnect(true).
		SetConnectRetry(true).
		SetConnectRetryInterval(5 * time.Second).
		SetOnConnectHandler(func(c mqtt.Client) {
			log.Println("[INFO] MQTT connected")
		}).
		SetConnectionLostHandler(func(c mqtt.Client, err error) {
			log.Printf("[WARN] MQTT connection lost: %v", err)
		})

	if username != "" {
		opts.SetUsername(username)
		opts.SetPassword(password)
	}

	client := mqtt.NewClient(opts)
	for i := 0; i < 10; i++ {
		if token := client.Connect(); token.Wait() && token.Error() != nil {
			log.Printf("[WARN] MQTT connect attempt %d/10: %v", i+1, token.Error())
			time.Sleep(3 * time.Second)
			continue
		}
		log.Println("[INFO] MQTT client connected")
		return client
	}
	log.Println("[WARN] Could not connect to MQTT broker, continuing without MQTT")
	return client
}

// restoreSubscriptions re-subscribes to all sensor and equipment MQTT topics on startup.
func restoreSubscriptions(db *sql.DB, client mqtt.Client) {
	if !client.IsConnected() {
		return
	}
	rows, _ := db.Query(`SELECT mqtt_topic FROM hardware.sensors`)
	if rows != nil {
		defer rows.Close()
		for rows.Next() {
			var topic string
			if rows.Scan(&topic) == nil {
				client.Subscribe(topic, 1, func(_ mqtt.Client, msg mqtt.Message) {
					log.Printf("[INFO] MQTT telemetry received on %s", msg.Topic())
				})
			}
		}
	}
}

func runMigrations(db *sql.DB) error {
	schema := `
	CREATE SCHEMA IF NOT EXISTS hardware;

	CREATE TABLE IF NOT EXISTS hardware.equipments (
		id             TEXT PRIMARY KEY,
		name           TEXT NOT NULL,
		operations     TEXT[] NOT NULL DEFAULT '{}',
		mqtt_topic     TEXT NOT NULL,
		api_url        TEXT,
		current_status TEXT NOT NULL DEFAULT 'OFF',
		created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
	);

	CREATE TABLE IF NOT EXISTS hardware.sensors (
		id               TEXT PRIMARY KEY,
		name             TEXT NOT NULL,
		parameter_ids    TEXT[] NOT NULL DEFAULT '{}',
		mqtt_topic       TEXT NOT NULL,
		api_url          TEXT,
		update_frequency INT NOT NULL DEFAULT 60,
		created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
	);

	CREATE TABLE IF NOT EXISTS hardware.parameters (
		id          TEXT PRIMARY KEY,
		unit        TEXT NOT NULL,
		description TEXT,
		created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
	);

	CREATE TABLE IF NOT EXISTS hardware.raw_sensor_data (
		id           SERIAL PRIMARY KEY,
		sensor_id    TEXT NOT NULL,
		parameter_id TEXT NOT NULL,
		value        DOUBLE PRECISION NOT NULL,
		timestamp    TIMESTAMPTZ NOT NULL DEFAULT NOW()
	);

	CREATE INDEX IF NOT EXISTS idx_raw_sensor_data_sensor_id    ON hardware.raw_sensor_data(sensor_id);
	CREATE INDEX IF NOT EXISTS idx_raw_sensor_data_parameter_id ON hardware.raw_sensor_data(parameter_id);
	CREATE INDEX IF NOT EXISTS idx_raw_sensor_data_timestamp    ON hardware.raw_sensor_data(timestamp DESC);
	`
	if _, err := db.Exec(schema); err != nil {
		return fmt.Errorf("hardware migration: %w", err)
	}
	log.Println("[INFO] Hardware migrations applied")
	return nil
}

// makeInternalRequest is a shared helper for inter-service REST calls.
func makeInternalRequest(method, url string, body []byte) (*http.Response, error) {
	req, err := http.NewRequest(method, url, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Internal-Service", "hardware-service")
	client := &http.Client{Timeout: 5 * time.Second}
	return client.Do(req)
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
