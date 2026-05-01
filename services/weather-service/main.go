package main

import (
	"log"
	"os"
	"strconv"

	"github.com/gin-gonic/gin"
)

var sbNotificationPublisher *AzureServiceBusNotificationPublisher

func main() {
	jwtSecret := getEnv("JWT_SECRET", "super-secret-jwt-key-change-in-production")
	owmAPIKey := getEnv("OWM_API_KEY", "") // Empty = use mock
	owmBaseURL := getEnv("OWM_BASE_URL", "https://api.openweathermap.org/data/2.5")
	latStr := getEnv("LOCATION_LAT", "6.9271") // Default: Colombo, Sri Lanka
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

	serviceBusConnection := getServiceBusConnection()
	serviceBusNotificationsTopic := getServiceBusNotificationsTopic()

	var err error
	sbNotificationPublisher, err = NewAzureServiceBusNotificationPublisher(serviceBusConnection, serviceBusNotificationsTopic)
	if err != nil {
		log.Printf("[WARN] Azure Service Bus notification publisher initialization failed: %v", err)
	}

	h := NewHandler(jwtSecret, owmAPIKey, owmBaseURL, lat, lon, cityName, useMock, sbNotificationPublisher)
	r := gin.New()
	r.Use(gin.Logger(), gin.Recovery())

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"status":   "ok",
			"service":  "weather-service",
			"mock_mode": useMock,
			"sb_notification_enabled": sbNotificationPublisher != nil && sbNotificationPublisher.IsConnected(),
		})
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
