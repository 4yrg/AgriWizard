package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	_ "github.com/lib/pq"
)

// ServiceStatus holds the shared service state.
type ServiceStatus struct {
	mu       sync.RWMutex
	db       *sql.DB
	ready    bool
	migrated bool
}

var rmqConsumer *RabbitMQConsumer
var sbConsumer *AzureServiceBusConsumer
var sbNotificationPublisher *AzureServiceBusNotificationPublisher

func (s *ServiceStatus) GetDB() *sql.DB {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.db
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

func (s *ServiceStatus) SetReady(db *sql.DB) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.db = db
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
	jwtSecret := getEnv("JWT_SECRET", "super-secret-jwt-key-change-in-production")
	hardwareURL := getEnv("HARDWARE_SERVICE_URL", "http://hardware-service:8082")
	weatherURL := getEnv("WEATHER_SERVICE_URL", "http://weather-service:8084")
	port := getEnv("PORT", "8083")

	rabbitmqUrl := getRabbitMQUrl()
	queueName := getQueueName()

	serviceBusConnection := getServiceBusConnection()
	serviceBusTopic := getServiceBusTopic()
	serviceBusSubscription := getServiceBusSubscription()
	serviceBusNotificationTopic := getServiceBusNotificationTopic()
	serviceBusNotificationSubscription := getServiceBusNotificationSubscription()
	notificationRecipient := getServiceBusNotificationRecipient()

	dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		dbHost, dbPort, dbUser, dbPass, dbName, dbSSLMode)

	status := &ServiceStatus{}

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
		c.JSON(http.StatusOK, gin.H{
			"status":                  s,
			"service":                 "analytics-service",
			"db_ready":                status.IsReady(),
			"migrated":                status.migrated,
			"rmq_ready":               rmqConsumer != nil && rmqConsumer.IsConnected(),
			"sb_connected":            sbConsumer != nil && sbConsumer.IsConnected(),
			"sb_notification_enabled": sbNotificationPublisher != nil && sbNotificationPublisher.IsConnected(),
		})
	})

	// Start HTTP server in background
	server := &http.Server{Addr: ":" + port, Handler: r}
	go func() {
		log.Printf("[INFO] Analytics Service starting on :%s", port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("[FATAL] Server: %v", err)
		}
	}()

	// Initialize Service Bus notification publisher
	var err error
	sbNotificationPublisher, err = NewAzureServiceBusNotificationPublisher(serviceBusConnection, serviceBusNotificationTopic)
	if err != nil {
		log.Printf("[WARN] Azure Service Bus notification publisher initialization failed: %v", err)
	}

	// Setup handler with dependencies
	h := NewHandler(status, jwtSecret, hardwareURL, weatherURL, sbNotificationPublisher)

	// Initialize Service Bus consumer (telemetry)
	rmqConsumer, err = NewRabbitMQConsumer(rabbitmqUrl, queueName, h)
	if err != nil {
		log.Printf("[WARN] RabbitMQ consumer initialization failed: %v", err)
	}

	// Initialize Azure Service Bus consumer (telemetry)
	sbConsumer, err = NewAzureServiceBusConsumer(serviceBusConnection, serviceBusTopic, serviceBusSubscription, h)
	if err != nil {
		log.Printf("[WARN] Azure Service Bus consumer initialization failed: %v", err)
	}

	validateServiceBusConfiguration(serviceBusConnection, serviceBusTopic, serviceBusSubscription, serviceBusNotificationTopic, serviceBusNotificationSubscription, notificationRecipient)

	// Start RabbitMQ consumer in background
	if rmqConsumer != nil && rmqConsumer.IsConnected() {
		go func() {
			<-rmqConsumer.Ready()
			log.Println("[INFO] RabbitMQ consumer ready")
			if err := rmqConsumer.Start(context.Background()); err != nil {
				log.Printf("[ERROR] RabbitMQ consumer error: %v", err)
			}
		}()
	}

	// Start Azure Service Bus consumer in background
	if sbConsumer != nil && sbConsumer.IsConnected() {
		go func() {
			<-sbConsumer.Ready()
			log.Println("[INFO] Azure Service Bus consumer ready")
			if err := sbConsumer.Start(context.Background()); err != nil {
				log.Printf("[ERROR] Azure Service Bus consumer error: %v", err)
			}
		}()
	}

	// Connect to database in background
	go func() {
		for {
			db, err := connectDB(dsn)
			if err != nil {
				log.Printf("[ERROR] DB: %v", err)
				log.Println("[WARN] Analytics init retry in 10s")
				time.Sleep(10 * time.Second)
				continue
			}

			if err := runMigrations(db); err != nil {
				log.Printf("[ERROR] Migrations: %v", err)
				db.Close()
				log.Println("[WARN] Analytics init retry in 10s")
				time.Sleep(10 * time.Second)
				continue
			}

			status.SetReady(db)
			status.SetMigrated()
			log.Println("[INFO] Analytics Service fully ready")
			return
		}
	}()

	// Setup API routes
	api := r.Group("/api/v1/analytics")
	api.Use(h.requireDB(), h.JWTAuthMiddleware())
	{
		api.POST("/thresholds", h.UpsertThreshold)
		api.GET("/thresholds/:parameterId", h.GetThreshold)

		api.POST("/rules", h.CreateRule)
		api.GET("/rules/:parameterId", h.GetRulesForParameter)

		api.GET("/decisions/summary", h.GetDecisionSummary)
		api.POST("/ingest", h.Ingest)

		api.GET("/summaries", h.GetDailySummaries)
		api.GET("/equipment-analytics", h.GetEquipmentAnalytics)
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
				db.SetMaxOpenConns(25)
				db.SetMaxIdleConns(5)
				db.SetConnMaxLifetime(5 * time.Minute)
				log.Println("[INFO] Database connected")
				return db, nil
			}
		}
		log.Printf("[WARN] DB attempt %d/10...", i+1)
		time.Sleep(3 * time.Second)
	}
	return nil, fmt.Errorf("db connect failed: %w", err)
}

func runMigrations(db *sql.DB) error {
	schema := `
	CREATE SCHEMA IF NOT EXISTS analytics;

	CREATE TABLE IF NOT EXISTS analytics.thresholds (
		id           TEXT PRIMARY KEY,
		parameter_id TEXT UNIQUE NOT NULL,
		min_value    DOUBLE PRECISION NOT NULL DEFAULT 0,
		max_value    DOUBLE PRECISION NOT NULL,
		is_enabled   BOOLEAN NOT NULL DEFAULT true,
		created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
		updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
	);

	CREATE TABLE IF NOT EXISTS analytics.automation_rules (
		id           TEXT PRIMARY KEY,
		threshold_id TEXT NOT NULL REFERENCES analytics.thresholds(id) ON DELETE CASCADE,
		equipment_id TEXT NOT NULL,
		low_action   TEXT NOT NULL,
		high_action  TEXT NOT NULL,
		created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
	);

	CREATE INDEX IF NOT EXISTS idx_rules_threshold ON analytics.automation_rules(threshold_id);

	CREATE TABLE IF NOT EXISTS analytics.daily_summaries (
		id           SERIAL PRIMARY KEY,
		parameter_id TEXT NOT NULL,
		avg_value    DOUBLE PRECISION NOT NULL,
		min_recorded DOUBLE PRECISION NOT NULL,
		max_recorded DOUBLE PRECISION NOT NULL,
		date         DATE NOT NULL,
		UNIQUE (parameter_id, date)
	);

	CREATE INDEX IF NOT EXISTS idx_summaries_date ON analytics.daily_summaries(date DESC);

	CREATE TABLE IF NOT EXISTS analytics.equipment_analysis (
		id           TEXT PRIMARY KEY,
		equipment_id TEXT NOT NULL,
		date         DATE NOT NULL,
		usage_count  INTEGER NOT NULL DEFAULT 0,
		efficiency_score DOUBLE PRECISION NOT NULL DEFAULT 100.0,
		last_action  TEXT,
		updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
		UNIQUE (equipment_id, date)
	);

	CREATE INDEX IF NOT EXISTS idx_equip_analysis_date ON analytics.equipment_analysis(date DESC);
	`
	if _, err := db.Exec(schema); err != nil {
		return fmt.Errorf("analytics migration: %w", err)
	}
	log.Println("[INFO] Analytics migrations applied")
	return nil
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func validateServiceBusConfiguration(connectionString, telemetryTopic, telemetrySubscription, notificationTopic, notificationSubscription, notificationRecipient string) {
	if connectionString == "" {
		log.Println("[WARN] SERVICE_BUS_CONNECTION not set; Azure Service Bus is disabled")
		return
	}

	if !strings.Contains(connectionString, "Endpoint=") || !strings.Contains(connectionString, "SharedAccessKey") {
		log.Println("[WARN] SERVICE_BUS_CONNECTION does not look like a valid Azure Service Bus connection string")
	}
	if telemetryTopic == "" || telemetrySubscription == "" || notificationTopic == "" || notificationSubscription == "" {
		log.Println("[WARN] Service Bus topic or subscription configuration is incomplete")
	}
	if telemetryTopic == notificationTopic {
		log.Printf("[WARN] Service Bus telemetry and notification topics are the same: %s", telemetryTopic)
	}
	if notificationRecipient == "" {
		log.Println("[WARN] Notification recipient is not configured; alerts will be skipped")
	}
}
