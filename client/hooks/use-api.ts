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

// ════════════════════════════════════════════════════════════════════════════
// Hardware Service Hooks
// ════════════════════════════════════════════════════════════════════════════

export function useEquipment() {
  return useSWR<Equipment[]>("equipment", async () => {
    const response = await hardwareApi.listEquipment();
    return response.data;
  });
}

export function useSensors() {
  return useSWR<Sensor[]>("sensors", async () => {
    const response = await hardwareApi.listSensors();
    return response.data;
  });
}

export function useParameters() {
  return useSWR<Parameter[]>("parameters", async () => {
    const response = await hardwareApi.listParameters();
    return response.data;
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
  });
}

export function useDailySummaries(date?: string) {
  return useSWR<DailySummary[]>(
    `summaries-${date || "today"}`,
    async () => {
      const response = await analyticsApi.getDailySummaries(date);
      return response.data;
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
    refreshInterval: 60000, // Refresh every minute
  });
}

export function useWeatherForecast() {
  return useSWR<WeatherForecast[]>("weather-forecast", async () => {
    const response = await weatherApi.getForecast();
    return response.data;
  }, {
    refreshInterval: 300000, // Refresh every 5 minutes
  });
}

export function useWeatherAlerts() {
  return useSWR<WeatherAlert[]>("weather-alerts", async () => {
    const response = await weatherApi.getAlerts();
    return response.data;
  }, {
    refreshInterval: 60000, // Refresh every minute
  });
}

export function useIrrigationRecommendation() {
  return useSWR<IrrigationRecommendation>("irrigation-recommendation", async () => {
    const response = await weatherApi.getRecommendations();
    return response.data;
  }, {
    refreshInterval: 300000, // Refresh every 5 minutes
  });
}
