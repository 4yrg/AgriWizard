package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"
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
	jwtSecret := getEnv("JWT_SECRET", "super-secret-jwt-key-change-in-production")
	hardwareURL := getEnv("HARDWARE_SERVICE_URL", "http://hardware-service:8082")
	weatherURL := getEnv("WEATHER_SERVICE_URL", "http://weather-service:8084")
	port := getEnv("PORT", "8083")

	dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		dbHost, dbPort, dbUser, dbPass, dbName)

	status := &ServiceStatus{}

	if getEnv("GIN_MODE", "debug") == "release" {
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
			"status":   s,
			"service":  "analytics-service",
			"db_ready": status.IsReady(),
			"migrated": status.migrated,
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

	// Connect to database in background
	go func() {
		db, err := connectDB(dsn)
		if err != nil {
			log.Printf("[ERROR] DB: %v", err)
			return
		}

		if err := runMigrations(db); err != nil {
			log.Printf("[ERROR] Migrations: %v", err)
			db.Close()
			return
		}

		status.SetReady(db)
		status.SetMigrated()
		log.Println("[INFO] Analytics Service fully ready")
	}()

	// Setup API routes
	h := NewHandler(status, jwtSecret, hardwareURL, weatherURL)
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
