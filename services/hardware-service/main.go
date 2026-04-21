package main

import (
	"bytes"
	"context"
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"
	"sync"
	"time"

	mqtt "github.com/eclipse/paho.mqtt.golang"
	"github.com/gin-gonic/gin"
	_ "github.com/lib/pq"
)

// ServiceStatus holds the shared service state.
type ServiceStatus struct {
	mu         sync.RWMutex
	db         *sql.DB
	mqttClient mqtt.Client
	ready      bool
	migrated   bool
}

func (s *ServiceStatus) GetDB() *sql.DB {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.db
}

func (s *ServiceStatus) GetMQTTClient() mqtt.Client {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.mqttClient
}

func (s *ServiceStatus) IsReady() bool {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.ready
}

func (s *ServiceStatus) IsMigrated() bool {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.migrated
}

func (s *ServiceStatus) IsMQTTConnected() bool {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.mqttClient != nil && s.mqttClient.IsConnected()
}

func (s *ServiceStatus) SetReady(db *sql.DB, mqttClient mqtt.Client) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.db = db
	s.mqttClient = mqttClient
	s.ready = true
}

func (s *ServiceStatus) SetMigrated() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.migrated = true
}

func main() {
	dbHost := getEnv("DB_HOST", "localhost")
	dbPort := getEnv("DB_PORT", "5432")
	dbUser := getEnv("DB_USER", "agriwizard")
	dbPass := getEnv("DB_PASSWORD", "agriwizard_secret")
	dbName := getEnv("DB_NAME", "agriwizard")
	dbSSLMode := getEnv("DB_SSLMODE", "disable")
	mqttBroker := getEnv("MQTT_BROKER", "tcp://localhost:1883")
	mqttUsername := getEnv("MQTT_USERNAME", "")
	mqttPassword := getEnv("MQTT_PASSWORD", "")
	jwtSecret := getEnv("JWT_SECRET", "super-secret-jwt-key-change-in-production")
	analyticsURL := getEnv("ANALYTICS_SERVICE_URL", "http://analytics-service:8083")
	port := getEnv("PORT", "8082")

	rabbitmqUrl := getRabbitMQUrl()
	queueName := getQueueName()

	serviceBusConnection := getServiceBusConnection()
	serviceBusTopic := getServiceBusTopic()

	dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		dbHost, dbPort, dbUser, dbPass, dbName, dbSSLMode)

	status := &ServiceStatus{}

	rmqPublisher, err := NewRabbitMQPublisher(rabbitmqUrl, queueName)
	if err != nil {
		log.Printf("[WARN] RabbitMQ publisher initialization failed: %v", err)
	}

	sbPublisher, err := NewAzureServiceBusPublisher(serviceBusConnection, serviceBusTopic)
	if err != nil {
		log.Printf("[WARN] Azure Service Bus publisher initialization failed: %v", err)
	}

	// --- Router ---
	if getEnv("GIN_MODE", "debug") == "debug" {
		gin.SetMode(gin.DebugMode)
	} else {
		gin.SetMode(gin.ReleaseMode)
	}

	r := gin.New()
	r.Use(gin.Logger(), gin.Recovery())

	// Health check - available immediately
	r.GET("/health", func(c *gin.Context) {
		s := "ok"
		if !status.IsReady() {
			s = "starting"
		}
		mqttClient := status.GetMQTTClient()
		mqttConnected := mqttClient != nil && mqttClient.IsConnected()
		rmqConnected := rmqPublisher != nil && rmqPublisher.IsConnected()
		sbConnected := sbPublisher != nil && sbPublisher.IsConnected()
		c.JSON(http.StatusOK, gin.H{
			"status":    s,
			"service":   "hardware-service",
			"db_ready":  status.IsReady(),
			"migrated":  status.migrated,
			"mqtt_conn": mqttConnected,
			"rmq_conn":  rmqConnected,
			"sb_conn":   sbConnected,
		})
	})

	// Start HTTP server in background
	server := &http.Server{Addr: ":" + port, Handler: r}
	go func() {
		log.Printf("[INFO] Hardware Service starting on :%s", port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("[FATAL] Server: %v", err)
		}
	}()

	// Connect to database and MQTT in background (retry until ready)
	go func() {
		for {
			db, err := connectDB(dsn)
			if err != nil {
				log.Printf("[ERROR] DB connect: %v", err)
				log.Println("[WARN] Hardware Service init retry in 10s")
				time.Sleep(10 * time.Second)
				continue
			}

			if err := runMigrations(db); err != nil {
				log.Printf("[ERROR] Migrations: %v", err)
				db.Close()
				log.Println("[WARN] Hardware Service init retry in 10s")
				time.Sleep(10 * time.Second)
				continue
			}

			mqttClient := connectMQTT(mqttBroker, mqttUsername, mqttPassword)
			restoreSubscriptions(db, mqttClient, rmqPublisher, sbPublisher)

			status.SetReady(db, mqttClient)
			status.SetMigrated()
			log.Println("[INFO] Hardware Service fully ready")
			return
		}
	}()

	// Setup API routes
	h := NewHandler(status, jwtSecret, analyticsURL, rmqPublisher, sbPublisher)
	api := r.Group("/api/v1/hardware")
	api.Use(h.requireDB(), h.JWTAuthMiddleware())
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

	// Block main thread
	<-context.Background().Done()
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
	if broker == "" {
		log.Println("[INFO] MQTT broker not configured, skipping MQTT")
		return nil
	}

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
func restoreSubscriptions(db *sql.DB, client mqtt.Client, rmqPublisher *RabbitMQPublisher, sbPublisher *AzureServiceBusPublisher) {
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
					// Also publish to RabbitMQ/Service Bus for analytics
					if rmqPublisher != nil && rmqPublisher.IsConnected() {
						log.Printf("[DEBUG] Would publish to RabbitMQ: %s", msg.Topic())
					}
					if sbPublisher != nil && sbPublisher.IsConnected() {
						log.Printf("[DEBUG] Would publish to Service Bus: %s", msg.Topic())
					}
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
