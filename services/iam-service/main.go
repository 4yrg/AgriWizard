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
	"github.com/google/uuid"
	_ "github.com/lib/pq"
	"golang.org/x/crypto/bcrypt"
)

// DBStatus holds the shared database connection and readiness state.
type DBStatus struct {
	mu       sync.RWMutex
	db       *sql.DB
	ready    bool
	migrated bool
}

var sbNotificationPublisher *AzureServiceBusNotificationPublisher

func (s *DBStatus) GetDB() *sql.DB {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.db
}

func (s *DBStatus) IsReady() bool {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.ready
}

func (s *DBStatus) IsMigrated() bool {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.migrated
}

func (s *DBStatus) SetReady(db *sql.DB) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.db = db
	s.ready = true
}

func (s *DBStatus) SetMigrated() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.migrated = true
}

func main() {
	// --- Configuration from environment ---
	dbHost := getEnv("DB_HOST", "localhost")
	dbPort := getEnv("DB_PORT", "5432")
	dbUser := getEnv("DB_USER", "agriwizard")
	dbPass := getEnv("DB_PASSWORD", "agriwizard_secret")
	dbName := getEnv("DB_NAME", "agriwizard")
	dbSSLMode := getEnv("DB_SSLMODE", "disable")
	jwtSecret := getEnv("JWT_SECRET", "super-secret-jwt-key-change-in-production")
	jwtIssuer := getEnv("JWT_ISSUER", "agriwizard-iam")
	jwtTTLHours := getEnv("JWT_TTL_HOURS", "24")
	port := getEnv("PORT", "8081")

	ttlDur, err := time.ParseDuration(jwtTTLHours + "h")
	if err != nil {
		log.Fatalf("[FATAL] Invalid JWT_TTL_HOURS: %v", err)
	}

	// --- Database Connection ---
	dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		dbHost, dbPort, dbUser, dbPass, dbName, dbSSLMode)

	dbStatus := &DBStatus{}

	// --- Router Setup ---
	if getEnv("GIN_MODE", "debug") == "release" {
		gin.SetMode(gin.ReleaseMode)
	}

	r := gin.New()
	r.Use(gin.Logger(), gin.Recovery())

	// Health check (unauthenticated) - available immediately
	r.GET("/health", func(c *gin.Context) {
		status := "ok"
		if !dbStatus.IsReady() {
			status = "starting"
		}
		c.JSON(http.StatusOK, gin.H{
			"status":                  status,
			"service":                 "iam-service",
			"db_ready":                dbStatus.IsReady(),
			"migrated":                dbStatus.IsMigrated(),
			"sb_notification_enabled": sbNotificationPublisher != nil && sbNotificationPublisher.IsConnected(),
		})
	})

	// --- Service Bus Setup ---
	serviceBusConnection := getServiceBusConnection()
	serviceBusNotificationsTopic := getServiceBusNotificationsTopic()

	sbNotificationPublisher, err = NewAzureServiceBusNotificationPublisher(serviceBusConnection, serviceBusNotificationsTopic)
	if err != nil {
		log.Printf("[WARN] Azure Service Bus notification publisher initialization failed: %v", err)
	}

	// Start HTTP server in background
	server := &http.Server{Addr: ":" + port, Handler: r}
	go func() {
		log.Printf("[INFO] IAM Service starting on :%s", port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("[FATAL] Server failed: %v", err)
		}
	}()

	// Connect to database in background (retry until ready)
	go func() {
		for {
			db, err := connectDB(dsn)
			if err != nil {
				log.Printf("[ERROR] Database connection failed: %v", err)
				log.Println("[WARN] IAM init retry in 10s")
				time.Sleep(10 * time.Second)
				continue
			}

			if err := runMigrations(db); err != nil {
				log.Printf("[ERROR] Migration failed: %v", err)
				db.Close()
				log.Println("[WARN] IAM init retry in 10s")
				time.Sleep(10 * time.Second)
				continue
			}

			dbStatus.SetReady(db)
			dbStatus.SetMigrated()
			log.Println("[INFO] IAM Service fully ready")
			return
		}
	}()

	// Start background job to create default admin user once DB is ready
	go func() {
		for i := 0; i < 30; i++ {
			if dbStatus.IsReady() && dbStatus.IsMigrated() {
				if err := createDefaultAdmin(dbStatus.GetDB()); err != nil {
					log.Printf("[WARN] Could not create default admin: %v", err)
				}
				break
			}
			time.Sleep(2 * time.Second)
		}
	}()

	// Setup API routes (will return 503 until DB is ready)
	h := NewHandler(dbStatus, jwtSecret, jwtIssuer, ttlDur, sbNotificationPublisher)

	// Public routes
	public := r.Group("/api/v1/iam")
	public.Use(h.requireDB())
	{
		public.POST("/register", h.Register)
		public.POST("/login", h.Login)
		public.GET("/introspect", h.Introspect)
	}

	// Protected routes
	protected := r.Group("/api/v1/iam")
	protected.Use(h.requireDB(), h.JWTAuthMiddleware())
	{
		protected.GET("/profile", h.GetProfile)
		protected.PUT("/profile", h.UpdateProfile)
	}

	// Block main thread
	<-context.Background().Done()
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

// createDefaultAdmin creates a default admin user if none exists.
func createDefaultAdmin(db *sql.DB) error {
	email := "admin@agriwizard.local"
	var exists bool
	err := db.QueryRow(`SELECT EXISTS(SELECT 1 FROM iam.users WHERE email = $1)`, email).Scan(&exists)
	if err != nil {
		return err
	}
	if exists {
		return nil
	}

	hash, err := bcrypt.GenerateFromPassword([]byte("admin123"), bcrypt.DefaultCost)
	if err != nil {
		return err
	}

	_, err = db.Exec(
		`INSERT INTO iam.users (id, email, password_hash, role, full_name) VALUES ($1, $2, $3, $4, $5)`,
		uuid.New().String(), email, string(hash), RoleAdmin, "System Admin",
	)
	if err != nil {
		return err
	}

	log.Println("[INFO] Default admin user created: admin@agriwizard.local / admin123")
	return nil
}
