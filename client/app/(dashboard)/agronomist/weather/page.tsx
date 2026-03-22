"use client";

import { useRequireAuth } from "@/lib/auth/context";
import {
  useCurrentWeather,
  useWeatherForecast,
  useWeatherAlerts,
  useIrrigationRecommendation,
} from "@/hooks/use-api";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  CardDescription,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Cloud,
  CloudRain,
  Droplets,
  Sun,
  Thermometer,
  Wind,
  AlertTriangle,
  MapPin,
  Clock,
} from "lucide-react";
import type { WeatherAlert } from "@/types/api";

function WeatherSkeleton() {
  return (
    <div className="space-y-6">
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        {[...Array(4)].map((_, i) => (
          <Card key={i}>
            <CardContent className="pt-6">
              <Skeleton className="h-12 w-full mb-4" />
              <Skeleton className="h-4 w-24" />
            </CardContent>
          </Card>
        ))}
      </div>
      <Card>
        <CardHeader>
          <Skeleton className="h-6 w-40" />
        </CardHeader>
        <CardContent>
          <Skeleton className="h-32 w-full" />
        </CardContent>
      </Card>
    </div>
  );
}

function AlertCard({ alert }: { alert: WeatherAlert }) {
  const severityStyles = {
    low: "bg-blue-500/10 border-blue-500/20 text-blue-600",
    medium: "bg-amber-500/10 border-amber-500/20 text-amber-600",
    high: "bg-orange-500/10 border-orange-500/20 text-orange-600",
    extreme: "bg-destructive/10 border-destructive/20 text-destructive",
  };

  return (
    <div className={`p-4 rounded-lg border ${severityStyles[alert.severity]}`}>
      <div className="flex items-center gap-2 mb-2">
        <AlertTriangle className="h-4 w-4" />
        <span className="font-medium">{alert.type}</span>
        <Badge
          variant="outline"
          className={`${severityStyles[alert.severity]} border-0`}
        >
          {alert.severity}
        </Badge>
      </div>
      <p className="text-sm">{alert.message}</p>
      <div className="flex items-center gap-4 mt-3 text-xs opacity-75">
        <div className="flex items-center gap-1">
          <Clock className="h-3 w-3" />
          <span>
            {new Date(alert.starts_at).toLocaleString()} -{" "}
            {new Date(alert.ends_at).toLocaleString()}
          </span>
        </div>
      </div>
    </div>
  );
}

function getWeatherIcon(description: string) {
  const lower = description.toLowerCase();
  if (lower.includes("rain") || lower.includes("shower")) {
    return CloudRain;
  }
  if (lower.includes("cloud")) {
    return Cloud;
  }
  return Sun;
}

function IrrigationGauge({ scale }: { scale: number }) {
  const percentage = Math.min(Math.max((scale / 2) * 100, 0), 100);
  const displayScale = scale.toFixed(1);

  let color = "bg-emerald-500";
  let recommendation = "Normal irrigation";

  if (scale <= 0.5) {
    color = "bg-blue-500";
    recommendation = "Reduce irrigation significantly";
  } else if (scale <= 0.8) {
    color = "bg-cyan-500";
    recommendation = "Reduce irrigation slightly";
  } else if (scale >= 1.5) {
    color = "bg-amber-500";
    recommendation = "Increase irrigation significantly";
  } else if (scale >= 1.2) {
    color = "bg-orange-400";
    recommendation = "Increase irrigation slightly";
  }

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <span className="text-sm font-medium">Irrigation Scale Factor</span>
        <span className="text-2xl font-bold">{displayScale}x</span>
      </div>
      <div className="h-3 bg-muted rounded-full overflow-hidden">
        <div
          className={`h-full ${color} transition-all duration-500`}
          style={{ width: `${percentage}%` }}
        />
      </div>
      <p className="text-sm text-muted-foreground">{recommendation}</p>
    </div>
  );
}

export default function WeatherPage() {
  const { isLoading: authLoading } = useRequireAuth("Agromist");
  const { data: weather, isLoading: weatherLoading } = useCurrentWeather();
  const { data: forecast, isLoading: forecastLoading } = useWeatherForecast();
  const { data: alerts, isLoading: alertsLoading } = useWeatherAlerts();
  const { data: recommendation, isLoading: recommendationLoading } =
    useIrrigationRecommendation();

  const isLoading =
    authLoading ||
    weatherLoading ||
    forecastLoading ||
    alertsLoading ||
    recommendationLoading;

  if (isLoading) {
    return (
      <div className="p-6">
        <div className="mb-6">
          <Skeleton className="h-8 w-48 mb-2" />
          <Skeleton className="h-4 w-64" />
        </div>
        <WeatherSkeleton />
      </div>
    );
  }

  const WeatherIcon = weather ? getWeatherIcon(weather.description) : Sun;

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-balance">Weather Intelligence</h1>
        <p className="text-muted-foreground">
          Current conditions, forecasts, and irrigation recommendations
        </p>
      </div>

      <div className="space-y-6">
        {/* Weather Alerts */}
        {alerts && alerts.length > 0 && (
          <div className="space-y-3">
            {alerts.map((alert) => (
              <AlertCard key={alert.id} alert={alert} />
            ))}
          </div>
        )}

        {/* Current Weather */}
        {weather && (
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <WeatherIcon className="h-5 w-5" />
                Current Conditions
              </CardTitle>
              {weather.location && (
                <CardDescription className="flex items-center gap-1">
                  <MapPin className="h-3.5 w-3.5" />
                  {weather.location.city_name}
                </CardDescription>
              )}
            </CardHeader>
            <CardContent>
              <div className="grid gap-6 md:grid-cols-2">
                <div className="flex items-center gap-6">
                  <div>
                    <p className="text-5xl font-bold">
                      {Math.round(weather.temperature_celsius)}°
                    </p>
                    <p className="text-muted-foreground capitalize text-lg">
                      {weather.description}
                    </p>
                  </div>
                  <WeatherIcon className="h-16 w-16 text-muted-foreground/50" />
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div className="flex items-center gap-3 p-3 rounded-lg bg-muted/50">
                    <Droplets className="h-5 w-5 text-blue-500" />
                    <div>
                      <p className="font-medium">
                        {weather.humidity_percent}%
                      </p>
                      <p className="text-xs text-muted-foreground">Humidity</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-3 p-3 rounded-lg bg-muted/50">
                    <Wind className="h-5 w-5 text-muted-foreground" />
                    <div>
                      <p className="font-medium">
                        {weather.wind_speed_kmh} km/h
                      </p>
                      <p className="text-xs text-muted-foreground">Wind</p>
                    </div>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>
        )}

        <div className="grid gap-6 lg:grid-cols-2">
          {/* Irrigation Recommendation */}
          {recommendation && (
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Droplets className="h-5 w-5" />
                  Irrigation Recommendation
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <IrrigationGauge scale={recommendation.scale} />

                <div className="p-3 rounded-lg bg-muted text-sm">
                  <p>{recommendation.reason}</p>
                </div>

                <div className="grid grid-cols-2 gap-4 pt-2">
                  <div className="flex items-center gap-2">
                    <Thermometer className="h-4 w-4 text-muted-foreground" />
                    <div>
                      <p className="text-sm font-medium">
                        {recommendation.current_temperature_celsius}°C
                      </p>
                      <p className="text-xs text-muted-foreground">
                        Temperature
                      </p>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <CloudRain className="h-4 w-4 text-blue-500" />
                    <div>
                      <p className="text-sm font-medium">
                        {recommendation.rain_chance_percent}%
                      </p>
                      <p className="text-xs text-muted-foreground">
                        Rain Chance
                      </p>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>
          )}

          {/* Forecast */}
          {forecast && forecast.length > 0 && (
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Cloud className="h-5 w-5" />
                  24-Hour Forecast
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-3">
                  {forecast.slice(0, 5).map((day, index) => {
                    const ForecastIcon = getWeatherIcon(day.description);
                    return (
                      <div
                        key={index}
                        className="flex items-center justify-between p-3 rounded-lg bg-muted/50"
                      >
                        <div className="flex items-center gap-3">
                          <ForecastIcon className="h-5 w-5 text-muted-foreground" />
                          <div>
                            <p className="font-medium text-sm">
                              {new Date(day.date).toLocaleDateString("en-US", {
                                weekday: "short",
                                month: "short",
                                day: "numeric",
                              })}
                            </p>
                            <p className="text-xs text-muted-foreground capitalize">
                              {day.description}
                            </p>
                          </div>
                        </div>
                        <div className="text-right">
                          <p className="font-medium">
                            {Math.round(day.temperature_high)}° /{" "}
                            {Math.round(day.temperature_low)}°
                          </p>
                          <div className="flex items-center gap-1 text-xs text-blue-500">
                            <CloudRain className="h-3 w-3" />
                            {day.precipitation_chance}%
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </CardContent>
            </Card>
          )}
        </div>
      </div>
    </div>
  );
}
