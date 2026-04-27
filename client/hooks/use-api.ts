import useSWR from "swr";
import {
  hardwareApi,
  analyticsApi,
  weatherApi,
} from "@/lib/api/client";
import type {
  Equipment,
  Sensor,
  Parameter,
  Threshold,
  AutomationRule,
  DecisionTableEntry,
  DailySummary,
  WeatherCondition,
  WeatherForecast,
  WeatherAlert,
  IrrigationRecommendation,
} from "@/types/api";

function parseRefreshInterval(
  envValue: string | undefined,
  fallbackMs: number
): number {
  const parsed = Number(envValue);
  if (!Number.isFinite(parsed) || parsed < 0) {
    return fallbackMs;
  }
  return parsed;
}

const REFRESH_INTERVALS = {
  equipment: parseRefreshInterval(
    process.env.NEXT_PUBLIC_REFRESH_EQUIPMENT_MS,
    0
  ),
  sensors: parseRefreshInterval(process.env.NEXT_PUBLIC_REFRESH_SENSORS_MS, 0),
  parameters: parseRefreshInterval(
    process.env.NEXT_PUBLIC_REFRESH_PARAMETERS_MS,
    0
  ),
  decisions: parseRefreshInterval(
    process.env.NEXT_PUBLIC_REFRESH_DECISIONS_MS,
    0
  ),
  dailySummaries: parseRefreshInterval(
    process.env.NEXT_PUBLIC_REFRESH_DAILY_SUMMARIES_MS,
    0
  ),
  weatherCurrent: parseRefreshInterval(
    process.env.NEXT_PUBLIC_REFRESH_WEATHER_CURRENT_MS,
    60000
  ),
  weatherForecast: parseRefreshInterval(
    process.env.NEXT_PUBLIC_REFRESH_WEATHER_FORECAST_MS,
    300000
  ),
  weatherAlerts: parseRefreshInterval(
    process.env.NEXT_PUBLIC_REFRESH_WEATHER_ALERTS_MS,
    60000
  ),
  irrigationRecommendation: parseRefreshInterval(
    process.env.NEXT_PUBLIC_REFRESH_IRRIGATION_RECOMMENDATION_MS,
    300000
  ),
};

// ════════════════════════════════════════════════════════════════════════════
// Hardware Service Hooks
// ════════════════════════════════════════════════════════════════════════════

export function useEquipment() {
  return useSWR<Equipment[]>("equipment", async () => {
    const response = await hardwareApi.listEquipment();
    return response.data;
  }, {
    refreshInterval: REFRESH_INTERVALS.equipment,
  });
}

export function useSensors() {
  return useSWR<Sensor[]>("sensors", async () => {
    const response = await hardwareApi.listSensors();
    return response.data;
  }, {
    refreshInterval: REFRESH_INTERVALS.sensors,
  });
}

export function useParameters() {
  return useSWR<Parameter[]>("parameters", async () => {
    const response = await hardwareApi.listParameters();
    return response.data;
  }, {
    refreshInterval: REFRESH_INTERVALS.parameters,
  });
}

// ════════════════════════════════════════════════════════════════════════════
// Analytics Service Hooks
// ════════════════════════════════════════════════════════════════════════════

export function useThreshold(parameterId: string) {
  return useSWR<Threshold>(
    parameterId ? `threshold-${parameterId}` : null,
    async () => {
      const response = await analyticsApi.getThreshold(parameterId);
      return response.data;
    }
  );
}

export function useRules(parameterId: string) {
  return useSWR<AutomationRule[]>(
    parameterId ? `rules-${parameterId}` : null,
    async () => {
      const response = await analyticsApi.getRules(parameterId);
      return response.data;
    }
  );
}

export function useDecisionSummary() {
  return useSWR<DecisionTableEntry[]>("decisions", async () => {
    const response = await analyticsApi.getDecisionSummary();
    return response.data;
  }, {
    refreshInterval: REFRESH_INTERVALS.decisions,
  });
}

export function useDailySummaries(date?: string) {
  return useSWR<DailySummary[]>(
    `summaries-${date || "today"}`,
    async () => {
      const response = await analyticsApi.getDailySummaries(date);
      return response.data;
    },
    {
      refreshInterval: REFRESH_INTERVALS.dailySummaries,
    }
  );
}

// ════════════════════════════════════════════════════════════════════════════
// Weather Service Hooks
// ════════════════════════════════════════════════════════════════════════════

export function useCurrentWeather() {
  return useSWR<WeatherCondition>("weather-current", async () => {
    const response = await weatherApi.getCurrentWeather();
    return response.data;
  }, {
    refreshInterval: REFRESH_INTERVALS.weatherCurrent,
  });
}

export function useWeatherForecast() {
  return useSWR<WeatherForecast[]>("weather-forecast", async () => {
    const response = await weatherApi.getForecast();
    return response.data;
  }, {
    refreshInterval: REFRESH_INTERVALS.weatherForecast,
  });
}

export function useWeatherAlerts() {
  return useSWR<WeatherAlert[]>("weather-alerts", async () => {
    const response = await weatherApi.getAlerts();
    return response.data;
  }, {
    refreshInterval: REFRESH_INTERVALS.weatherAlerts,
  });
}

export function useIrrigationRecommendation() {
  return useSWR<IrrigationRecommendation>("irrigation-recommendation", async () => {
    const response = await weatherApi.getRecommendations();
    return response.data;
  }, {
    refreshInterval: REFRESH_INTERVALS.irrigationRecommendation,
  });
}
