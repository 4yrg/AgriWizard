package main

import (
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

// Handler holds shared dependencies.
type Handler struct {
	jwtSecret   string
	owmAPIKey   string
	owmBaseURL  string
	latitude    float64
	longitude   float64
	cityName    string
	useMock     bool
}

// NewHandler creates a new Handler.
func NewHandler(jwtSecret, owmAPIKey, owmBaseURL string, lat, lon float64, city string, useMock bool) *Handler {
	return &Handler{
		jwtSecret:  jwtSecret,
		owmAPIKey:  owmAPIKey,
		owmBaseURL: owmBaseURL,
		latitude:   lat,
		longitude:  lon,
		cityName:   city,
		useMock:    useMock,
	}
}

// GetCurrentWeather godoc
// @Summary      Get current local weather data
// @Tags         weather
// @Produce      json
// @Security     BearerAuth
// @Success      200  {object}  SuccessResponse
// @Router       /api/v1/weather/current [get]
func (h *Handler) GetCurrentWeather(c *gin.Context) {
	var condition WeatherCondition
	var err error

	if h.useMock || h.owmAPIKey == "" {
		condition = h.mockCurrentWeather()
	} else {
		condition, err = h.fetchCurrentWeather()
		if err != nil {
			log.Printf("[WARN] GetCurrentWeather: OWM fetch failed: %v, falling back to mock", err)
			condition = h.mockCurrentWeather()
		}
	}
	c.JSON(http.StatusOK, SuccessResponse{Data: condition})
}

// GetForecast godoc
// @Summary      Get 24-hour precipitation and temperature forecast
// @Tags         weather
// @Produce      json
// @Security     BearerAuth
// @Success      200  {object}  SuccessResponse
// @Router       /api/v1/weather/forecast [get]
func (h *Handler) GetForecast(c *gin.Context) {
	var forecast WeatherForecast
	var err error

	if h.useMock || h.owmAPIKey == "" {
		forecast = h.mockForecast()
	} else {
		forecast, err = h.fetchForecast()
		if err != nil {
			log.Printf("[WARN] GetForecast: OWM fetch failed: %v, falling back to mock", err)
			forecast = h.mockForecast()
		}
	}
	c.JSON(http.StatusOK, SuccessResponse{Data: forecast})
}

// GetAlerts godoc
// @Summary      Check for active extreme weather warnings
// @Tags         weather
// @Produce      json
// @Security     BearerAuth
// @Success      200  {object}  SuccessResponse
// @Router       /api/v1/weather/alerts [get]
func (h *Handler) GetAlerts(c *gin.Context) {
	alerts := h.generateAlerts()
	c.JSON(http.StatusOK, SuccessResponse{Data: alerts})
}

// GetRecommendations godoc
// @Summary      Get irrigation scale factor based on current conditions
// @Description  Returns a scale factor (e.g. 1.2 = irrigate 20% more) based on temperature and rain chance
// @Tags         weather
// @Produce      json
// @Security     BearerAuth
// @Success      200  {object}  SuccessResponse
// @Router       /api/v1/weather/recommendations [get]
func (h *Handler) GetRecommendations(c *gin.Context) {
	var condition WeatherCondition
	var forecast WeatherForecast

	if h.useMock || h.owmAPIKey == "" {
		condition = h.mockCurrentWeather()
		forecast = h.mockForecast()
	} else {
		var err error
		condition, err = h.fetchCurrentWeather()
		if err != nil {
			condition = h.mockCurrentWeather()
		}
		forecast, err = h.fetchForecast()
		if err != nil {
			forecast = h.mockForecast()
		}
	}

	rec := h.calculateRecommendation(condition, forecast)
	log.Printf("[INFO] GetRecommendations: scale=%.2f temp=%.1f rain=%.1f%%", rec.Scale, rec.Temperature, rec.RainChance)
	c.JSON(http.StatusOK, SuccessResponse{Data: rec})
}

// ──────────────────────────────────────────────
// Recommendation Logic
// ──────────────────────────────────────────────

// calculateRecommendation computes the irrigation scale factor.
// Rules:
//   temp > 38°C            → scale 1.4 (extreme heat, irrigate much more)
//   temp 35-38°C           → scale 1.2 (hot, irrigate more)
//   temp 20-35°C           → scale 1.0 (normal)
//   temp < 20°C            → scale 0.8 (cool, irrigate less)
//   rain chance >= 90%     → scale 0.0 (skip irrigation entirely)
//   rain chance >= 60%     → scale 0.5 (halve irrigation)
func (h *Handler) calculateRecommendation(condition WeatherCondition, forecast WeatherForecast) IrrigationRecommendation {
	temp := condition.Temperature
	// Find max rain probability in next 12 hours
	maxRainChance := 0.0
	now := time.Now()
	for _, entry := range forecast.Entries {
		if entry.Timestamp.Before(now.Add(12 * time.Hour)) {
			if entry.ProbabilityOfRain > maxRainChance {
				maxRainChance = entry.ProbabilityOfRain
			}
		}
	}

	var scale float64
	var reason string

	switch {
	case maxRainChance >= 90:
		scale = 0.0
		reason = fmt.Sprintf("Rain is %.0f%% likely in the next 12h — skip irrigation to conserve water", maxRainChance)
	case maxRainChance >= 60:
		scale = 0.5
		reason = fmt.Sprintf("Moderate rain chance (%.0f%%) — reduce irrigation by 50%%", maxRainChance)
	case temp > 38:
		scale = 1.4
		reason = fmt.Sprintf("Extreme heat (%.1f°C) — increase irrigation by 40%%", temp)
	case temp > 35:
		scale = 1.2
		reason = fmt.Sprintf("Hot conditions (%.1f°C) — increase irrigation by 20%%", temp)
	case temp < 20:
		scale = 0.8
		reason = fmt.Sprintf("Cool temperature (%.1f°C) — reduce irrigation by 20%%", temp)
	default:
		scale = 1.0
		reason = fmt.Sprintf("Normal conditions (%.1f°C, %.0f%% rain) — standard irrigation", temp, maxRainChance)
	}

	return IrrigationRecommendation{
		Scale:       scale,
		Reason:      reason,
		Temperature: temp,
		RainChance:  maxRainChance,
	}
}

// ──────────────────────────────────────────────
// Live OWM API Fetchers
// ──────────────────────────────────────────────

func (h *Handler) fetchCurrentWeather() (WeatherCondition, error) {
	url := fmt.Sprintf("%s/weather?lat=%.4f&lon=%.4f&units=metric&appid=%s",
		h.owmBaseURL, h.latitude, h.longitude, h.owmAPIKey)

	resp, err := http.Get(url)
	if err != nil {
		return WeatherCondition{}, err
	}
	defer resp.Body.Close()

	var owm OpenWeatherMapResponse
	if err := json.NewDecoder(resp.Body).Decode(&owm); err != nil {
		return WeatherCondition{}, err
	}
	if resp.StatusCode != http.StatusOK {
		return WeatherCondition{}, fmt.Errorf("OWM returned status %d", resp.StatusCode)
	}

	desc := ""
	if len(owm.Weather) > 0 {
		desc = owm.Weather[0].Description
	}

	return WeatherCondition{
		Location:    Location{Latitude: h.latitude, Longitude: h.longitude, CityName: owm.Name},
		Temperature: owm.Main.Temp,
		Humidity:    owm.Main.Humidity,
		WindSpeed:   owm.Wind.Speed * 3.6, // m/s to km/h
		Description: desc,
		FetchedAt:   time.Now().UTC(),
	}, nil
}

func (h *Handler) fetchForecast() (WeatherForecast, error) {
	url := fmt.Sprintf("%s/forecast?lat=%.4f&lon=%.4f&units=metric&cnt=8&appid=%s",
		h.owmBaseURL, h.latitude, h.longitude, h.owmAPIKey)

	resp, err := http.Get(url)
	if err != nil {
		return WeatherForecast{}, err
	}
	defer resp.Body.Close()

	var owmForecast OpenWeatherMapForecastResponse
	if err := json.NewDecoder(resp.Body).Decode(&owmForecast); err != nil {
		return WeatherForecast{}, err
	}

	var entries []ForecastEntry
	for _, item := range owmForecast.List {
		desc := ""
		if len(item.Weather) > 0 {
			desc = item.Weather[0].Description
		}
		rain := 0.0
		if item.Rain != nil {
			rain = item.Rain.ThreeH
		}
		entries = append(entries, ForecastEntry{
			Timestamp:           time.Unix(item.Dt, 0).UTC(),
			Temperature:         item.Main.Temp,
			Humidity:            item.Main.Humidity,
			ProbabilityOfRain:   item.Pop * 100,
			PrecipitationAmount: rain,
			Description:         desc,
		})
	}

	return WeatherForecast{
		Location:    Location{Latitude: h.latitude, Longitude: h.longitude, CityName: owmForecast.City.Name},
		GeneratedAt: time.Now().UTC(),
		Entries:     entries,
	}, nil
}

// ──────────────────────────────────────────────
// Mock Data Generators
// ──────────────────────────────────────────────

func (h *Handler) mockCurrentWeather() WeatherCondition {
	// Simulate realistic tropical greenhouse conditions
	baseTemp := 28.0 + rand.Float64()*10 // 28-38°C
	return WeatherCondition{
		Location:    Location{Latitude: h.latitude, Longitude: h.longitude, CityName: h.cityName},
		Temperature: baseTemp,
		Humidity:    60 + rand.Float64()*30,
		WindSpeed:   5 + rand.Float64()*15,
		Description: "partly cloudy",
		FetchedAt:   time.Now().UTC(),
	}
}

func (h *Handler) mockForecast() WeatherForecast {
	now := time.Now().UTC()
	var entries []ForecastEntry
	for i := 0; i < 8; i++ {
		rainChance := rand.Float64() * 100
		entries = append(entries, ForecastEntry{
			Timestamp:           now.Add(time.Duration(i*3) * time.Hour),
			Temperature:         25 + rand.Float64()*15,
			Humidity:            55 + rand.Float64()*35,
			ProbabilityOfRain:   rainChance,
			PrecipitationAmount: rainChance / 100 * rand.Float64() * 5,
			Description:         []string{"clear sky", "few clouds", "scattered clouds", "light rain"}[rand.Intn(4)],
		})
	}
	return WeatherForecast{
		Location:    Location{Latitude: h.latitude, Longitude: h.longitude, CityName: h.cityName},
		GeneratedAt: now,
		Entries:     entries,
	}
}

func (h *Handler) generateAlerts() []WeatherAlert {
	// Simulate occasional alerts for demo purposes
	var alerts []WeatherAlert
	// Use deterministic seed based on hour so alerts don't flicker every request
	r := rand.New(rand.NewSource(int64(time.Now().Hour())))
	if r.Float64() < 0.3 { // 30% chance of an alert in any given hour
		alerts = append(alerts, WeatherAlert{
			Type:      "extreme_heat",
			Severity:  "medium",
			Message:   "Ambient temperature exceeds 35°C. Consider increasing ventilation and irrigation.",
			StartsAt:  time.Now().UTC(),
			ExpiresAt: time.Now().UTC().Add(4 * time.Hour),
		})
	}
	if alerts == nil {
		alerts = []WeatherAlert{}
	}
	return alerts
}

// ──────────────────────────────────────────────
// JWT Middleware
// ──────────────────────────────────────────────

// JWTAuthMiddleware validates Bearer tokens for protected routes.
func (h *Handler) JWTAuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Allow internal service calls
		if c.GetHeader("X-Internal-Service") != "" {
			c.Next()
			return
		}
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
			c.AbortWithStatusJSON(http.StatusUnauthorized, ErrorResponse{Error: "missing_token"})
			return
		}
		tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
		token, err := jwt.Parse(tokenStr, func(t *jwt.Token) (interface{}, error) {
			if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, jwt.ErrSignatureInvalid
			}
			return []byte(h.jwtSecret), nil
		})
		if err != nil || !token.Valid {
			c.AbortWithStatusJSON(http.StatusUnauthorized, ErrorResponse{Error: "invalid_token"})
			return
		}
		claims, _ := token.Claims.(jwt.MapClaims)
		c.Set("user_id", claims["user_id"])
		c.Set("role", claims["role"])
		c.Next()
	}
}
