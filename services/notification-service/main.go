package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func main() {
	// ---- Configuration (env vars with sensible defaults) ----
	port := getEnv("PORT", "8085")
	dbHost := getEnv("DB_HOST", "localhost")
	dbPort := getEnv("DB_PORT", "5432")
	dbUser := getEnv("DB_USER", "notification")
	dbPass := getEnv("DB_PASSWORD", "notification_secret")
	dbName := getEnv("DB_NAME", "notification")
	natsURL := getEnv("NATS_URL", "nats://localhost:4222")
	smtpHost := getEnv("SMTP_HOST", "localhost")
	smtpPort := getEnv("SMTP_PORT", "1025")
	smtpFrom := getEnv("SMTP_FROM", "noreply@notification.local")
	smtpUser := getEnv("SMTP_USERNAME", "")
	smtpPass := getEnv("SMTP_PASSWORD", "")

	sbConnection := getEnv("SERVICE_BUS_CONNECTION", "")
	sbNamespace := getEnv("SERVICE_BUS_NAMESPACE", "agriwizard-sb")
	sbTopic := getEnv("SERVICE_BUS_TOPIC", "notifications")
	sbSubscription := getEnv("SERVICE_BUS_SUBSCRIPTION", "notification-service")

	dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		dbHost, dbPort, dbUser, dbPass, dbName)

	// ---- Database ----
	db, err := ConnectDB(dsn)
	if err != nil {
		log.Fatalf("[FATAL] %v", err)
	}
	defer db.Close()

	if err := RunMigrations(db); err != nil {
		log.Fatalf("[FATAL] %v", err)
	}

	store := NewStore(db)

	// ---- Template engine ----
	engine := NewTemplateEngine(store)

	// ---- Dispatcher + channels ----
	dispatcher := NewDispatcher(store, engine)

	dispatcher.RegisterChannel(&EmailSender{
		Host:     smtpHost,
		Port:     smtpPort,
		From:     smtpFrom,
		Username: smtpUser,
		Password: smtpPass,
	})

	// ---- NATS JetStream consumer (fallback) ----
	consumer, err := StartConsumer(natsURL, dispatcher)
	if err != nil {
		log.Printf("[WARN] NATS consumer failed to start: %v", err)
	} else {
		defer consumer.Close()
	}

	// ---- Azure Service Bus consumer ----
	sbConsumer, err := NewServiceBusConsumer(sbConnection, sbNamespace, sbTopic, sbSubscription, dispatcher)
	if err != nil {
		log.Printf("[WARN] Service Bus consumer initialization failed: %v", err)
	}
	if sbConsumer != nil && sbConsumer.IsConnected() {
		go func() {
			<-sbConsumer.Ready()
			log.Println("[INFO] Service Bus consumer ready")
			if err := sbConsumer.Start(context.Background()); err != nil {
				log.Printf("[ERROR] Service Bus consumer error: %v", err)
			}
		}()
	}

	// ---- HTTP server ----
	mux := http.NewServeMux()
	handler := NewHandler(store, dispatcher)
	handler.RegisterRoutes(mux)

	// CORS middleware
	wrappedMux := corsMiddleware(mux)

	server := &http.Server{
		Addr:         ":" + port,
		Handler:      wrappedMux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
	}

	// Start server in goroutine
	go func() {
		log.Printf("[INFO] Notification Service listening on :%s", port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("[FATAL] Server: %v", err)
		}
	}()

	// ---- Graceful shutdown ----
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("[INFO] Shutting down...")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	server.Shutdown(ctx)
	log.Println("[INFO] Notification Service stopped")
}

// corsMiddleware adds permissive CORS headers (suitable for dev/testing).
func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
