package main

import "time"

// WeatherCondition holds current environmental data.
type WeatherCondition struct {
	Location    Location  `json:"location"`
	Temperature float64   `json:"temperature_celsius"`
	Humidity    float64   `json:"humidity_percent"`
	WindSpeed   float64   `json:"wind_speed_kmh"`
	Description string    `json:"description"`
	FetchedAt   time.Time `json:"fetched_at"`
}

// Location holds geographical coordinates.
type Location struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
	CityName  string  `json:"city_name"`
}

// ForecastEntry is a single point in a weather forecast.
type ForecastEntry struct {
	Timestamp           time.Time `json:"timestamp"`
	Temperature         float64   `json:"temperature_celsius"`
	Humidity            float64   `json:"humidity_percent"`
	ProbabilityOfRain   float64   `json:"probability_of_rain_percent"`
	PrecipitationAmount float64   `json:"precipitation_mm"`
	Description         string    `json:"description"`
}

// WeatherForecast is a collection of forecast entries.
type WeatherForecast struct {
	Location    Location        `json:"location"`
	GeneratedAt time.Time       `json:"generated_at"`
	Entries     []ForecastEntry `json:"entries"`
}

// WeatherAlert represents a severe weather warning.
type WeatherAlert struct {
	Type      string    `json:"type"`     // "extreme_heat", "storm", "frost"
	Severity  string    `json:"severity"` // "low", "medium", "high", "critical"
	Message   string    `json:"message"`
	StartsAt  time.Time `json:"starts_at"`
	ExpiresAt time.Time `json:"expires_at"`
}

// IrrigationRecommendation provides a scale factor for irrigation decisions.
type IrrigationRecommendation struct {
	Scale       float64 `json:"scale"`
	Reason      string  `json:"reason"`
	Temperature float64 `json:"current_temperature_celsius"`
	RainChance  float64 `json:"rain_chance_percent"`
}

// OpenWeatherMapResponse mirrors the structure of the OWM current weather API.
type OpenWeatherMapResponse struct {
	Name string `json:"name"`
	Main struct {
		Temp     float64 `json:"temp"`
		Humidity float64 `json:"humidity"`
	} `json:"main"`
	Wind struct {
		Speed float64 `json:"speed"`
	} `json:"wind"`
	Weather []struct {
		Description string `json:"description"`
	} `json:"weather"`
	Cod int `json:"cod"`
}

// OpenWeatherMapForecastResponse mirrors the OWM 5-day forecast API structure.
type OpenWeatherMapForecastResponse struct {
	City struct {
		Name  string `json:"name"`
		Coord struct {
			Lat float64 `json:"lat"`
			Lon float64 `json:"lon"`
		} `json:"coord"`
	} `json:"city"`
	List []struct {
		Dt   int64 `json:"dt"`
		Main struct {
			Temp     float64 `json:"temp"`
			Humidity float64 `json:"humidity"`
		} `json:"main"`
		Pop  float64 `json:"pop"` // Probability of precipitation
		Rain *struct {
			ThreeH float64 `json:"3h"`
		} `json:"rain,omitempty"`
		Weather []struct {
			Description string `json:"description"`
		} `json:"weather"`
	} `json:"list"`
}

// ErrorResponse is the standard error payload.
type ErrorResponse struct {
	Error   string `json:"error"`
	Message string `json:"message,omitempty"`
}

// SuccessResponse is the standard success payload.
type SuccessResponse struct {
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
}
