package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	_ "github.com/lib/pq"
)

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
	db, err := connectDB(dsn)
	if err != nil {
		log.Fatalf("[FATAL] DB: %v", err)
	}
	defer db.Close()

	if err := runMigrations(db); err != nil {
		log.Fatalf("[FATAL] Migrations: %v", err)
	}

	if getEnv("GIN_MODE", "debug") == "release" {
		gin.SetMode(gin.ReleaseMode)
	}

	h := NewHandler(db, jwtSecret, hardwareURL, weatherURL)
	r := gin.New()
	r.Use(gin.Logger(), gin.Recovery())

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "analytics-service"})
	})

	api := r.Group("/api/v1/analytics")
	api.Use(h.JWTAuthMiddleware())
	{
		api.POST("/thresholds", h.UpsertThreshold)
		api.GET("/thresholds/:parameterId", h.GetThreshold)

		api.POST("/rules", h.CreateRule)
		api.GET("/rules/:parameterId", h.GetRulesForParameter)

		api.GET("/decisions/summary", h.GetDecisionSummary)
		api.POST("/ingest", h.Ingest)

		api.GET("/summaries", h.GetDailySummaries)
	}

	log.Printf("[INFO] Analytics Service starting on :%s", port)
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
