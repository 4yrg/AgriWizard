package main

import (
	"log"
	"os"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/nats-io/nats.go"
)

func main() {
	jwtSecret := getEnv("JWT_SECRET", "super-secret-jwt-key-change-in-production")
	owmAPIKey := getEnv("OWM_API_KEY", "") // Empty = use mock
	owmBaseURL := getEnv("OWM_BASE_URL", "https://api.openweathermap.org/data/2.5")
	latStr := getEnv("LOCATION_LAT", "6.9271")  // Default: Colombo, Sri Lanka
	lonStr := getEnv("LOCATION_LON", "79.8612")
	cityName := getEnv("LOCATION_CITY", "Colombo")
	useMockStr := getEnv("USE_MOCK", "true")
	port := getEnv("PORT", "8084")

	lat, _ := strconv.ParseFloat(latStr, 64)
	lon, _ := strconv.ParseFloat(lonStr, 64)
	useMock := useMockStr == "true" || owmAPIKey == ""

	if useMock {
		log.Println("[INFO] Weather Service: running with MOCK data (set OWM_API_KEY to use live data)")
	} else {
		log.Println("[INFO] Weather Service: running with LIVE OpenWeatherMap data")
	}

	if getEnv("GIN_MODE", "debug") == "release" {
		gin.SetMode(gin.ReleaseMode)
	}

	// --- NATS Connection (optional) ---
	var js nats.JetStreamContext
	natsURL := getEnv("NATS_URL", "nats://localhost:4222")
	nc, err := nats.Connect(natsURL,
		nats.RetryOnFailedConnect(true),
		nats.MaxReconnects(-1),
		nats.ReconnectWait(2*time.Second),
	)
	if err != nil {
		log.Printf("[WARN] NATS connection failed: %v — notifications disabled", err)
	} else {
		js, err = nc.JetStream()
		if err != nil {
			log.Printf("[WARN] JetStream init failed: %v — notifications disabled", err)
		} else {
			log.Printf("[INFO] NATS connected: %s", natsURL)
		}
	}

	h := NewHandler(jwtSecret, owmAPIKey, owmBaseURL, lat, lon, cityName, useMock, js)
	r := gin.New()
	r.Use(gin.Logger(), gin.Recovery())

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "weather-service", "mock_mode": useMock})
	})

	api := r.Group("/api/v1/weather")
	api.Use(h.JWTAuthMiddleware())
	{
		api.GET("/current", h.GetCurrentWeather)
		api.GET("/forecast", h.GetForecast)
		api.GET("/alerts", h.GetAlerts)
		api.GET("/recommendations", h.GetRecommendations)
	}

	log.Printf("[INFO] Weather Service starting on :%s", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatalf("[FATAL] Server: %v", err)
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
