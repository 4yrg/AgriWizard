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
	// --- Configuration from environment ---
	dbHost := getEnv("DB_HOST", "localhost")
	dbPort := getEnv("DB_PORT", "5432")
	dbUser := getEnv("DB_USER", "agriwizard")
	dbPass := getEnv("DB_PASSWORD", "agriwizard_secret")
	dbName := getEnv("DB_NAME", "agriwizard")
	jwtSecret := getEnv("JWT_SECRET", "super-secret-jwt-key-change-in-production")
	jwtTTLHours := getEnv("JWT_TTL_HOURS", "24")
	port := getEnv("PORT", "8081")

	ttlDur, err := time.ParseDuration(jwtTTLHours + "h")
	if err != nil {
		log.Fatalf("[FATAL] Invalid JWT_TTL_HOURS: %v", err)
	}

	// --- Database Connection ---
	dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		dbHost, dbPort, dbUser, dbPass, dbName)

	db, err := connectDB(dsn)
	if err != nil {
		log.Fatalf("[FATAL] Could not connect to database: %v", err)
	}
	defer db.Close()

	if err := runMigrations(db); err != nil {
		log.Fatalf("[FATAL] Migration failed: %v", err)
	}

	// --- Router Setup ---
	if getEnv("GIN_MODE", "debug") == "release" {
		gin.SetMode(gin.ReleaseMode)
	}

	h := NewHandler(db, jwtSecret, ttlDur)
	r := gin.New()
	r.Use(gin.Logger(), gin.Recovery())

	// Health check (unauthenticated)
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "iam-service"})
	})

	// Public routes
	public := r.Group("/api/v1/iam")
	{
		public.POST("/register", h.Register)
		public.POST("/login", h.Login)
		public.GET("/introspect", h.Introspect)
	}

	// Protected routes
	protected := r.Group("/api/v1/iam")
	protected.Use(h.JWTAuthMiddleware())
	{
		protected.GET("/profile", h.GetProfile)
		protected.PUT("/profile", h.UpdateProfile)
	}

	log.Printf("[INFO] IAM Service starting on :%s", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatalf("[FATAL] Server failed: %v", err)
	}
}

// connectDB attempts to connect to Postgres with retry logic.
func connectDB(dsn string) (*sql.DB, error) {
	var db *sql.DB
	var err error
	for i := 0; i < 10; i++ {
		db, err = sql.Open("postgres", dsn)
		if err == nil {
			if pingErr := db.Ping(); pingErr == nil {
				log.Println("[INFO] Database connected successfully")
				db.SetMaxOpenConns(25)
				db.SetMaxIdleConns(5)
				db.SetConnMaxLifetime(5 * time.Minute)
				return db, nil
			}
		}
		log.Printf("[WARN] DB connection attempt %d/10 failed, retrying in 3s...", i+1)
		time.Sleep(3 * time.Second)
	}
	return nil, fmt.Errorf("could not connect after 10 attempts: %w", err)
}

// runMigrations creates the IAM schema and tables if they don't exist.
func runMigrations(db *sql.DB) error {
	schema := `
	CREATE SCHEMA IF NOT EXISTS iam;

	CREATE TABLE IF NOT EXISTS iam.users (
		id            TEXT PRIMARY KEY,
		email         TEXT UNIQUE NOT NULL,
		password_hash TEXT NOT NULL,
		role          TEXT NOT NULL DEFAULT 'Agromist',
		full_name     TEXT NOT NULL,
		phone         TEXT,
		created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
		updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
	);

	CREATE INDEX IF NOT EXISTS idx_iam_users_email ON iam.users(email);
	`
	if _, err := db.Exec(schema); err != nil {
		return fmt.Errorf("migration error: %w", err)
	}
	log.Println("[INFO] IAM migrations applied successfully")
	return nil
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
