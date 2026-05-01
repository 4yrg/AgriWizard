// ════════════════════════════════════════════════════════════════════════════
// AgriWizard API Client - Type-safe fetch wrapper
// ════════════════════════════════════════════════════════════════════════════

import type {
  LoginRequest,
  LoginResponse,
  RegisterRequest,
  SuccessResponse,
  UserDTO,
  UpdateProfileRequest,
  Equipment,
  CreateEquipmentRequest,
  UpdateEquipmentRequest,
  ControlCommand,
  Sensor,
  CreateSensorRequest,
  UpdateSensorRequest,
  Parameter,
  CreateParameterRequest,
  TelemetryPayload,
  Threshold,
  UpsertThresholdRequest,
  AutomationRule,
  CreateRuleRequest,
  DecisionTableEntry,
  DailySummary,
  WeatherCondition,
  WeatherForecast,
  WeatherAlert,
  IrrigationRecommendation,
  Notification,
  UnreadCountResponse,
  EquipmentAnalysis,
} from "@/types/api";

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8080";

// ── API Error ───────────────────────────────────────────────────────────────

export class ApiError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string
  ) {
    super(message);
    this.name = "ApiError";
  }
}

// ── Fetch Wrapper ───────────────────────────────────────────────────────────

async function apiFetch<T>(
  endpoint: string,
  options: RequestInit = {}
): Promise<T> {
  const token = typeof window !== "undefined" ? localStorage.getItem("auth_token") : null;

  const headers: HeadersInit = {
    "Content-Type": "application/json",
    ...options.headers,
  };

  if (token) {
    (headers as Record<string, string>)["Authorization"] = `Bearer ${token}`;
  }

  const response = await fetch(`${API_BASE_URL}${endpoint}`, {
    ...options,
    headers,
  });

  if (!response.ok) {
    const error = await response.json().catch(() => ({
      error: "unknown_error",
      message: "An unexpected error occurred",
    }));
    throw new ApiError(response.status, error.error, error.message);
  }

  // Handle 204 No Content
  if (response.status === 204) {
    return {} as T;
  }

  return response.json();
}

// ════════════════════════════════════════════════════════════════════════════
// IAM Service API
// ════════════════════════════════════════════════════════════════════════════

export const iamApi = {
  register: (data: RegisterRequest) =>
    apiFetch<SuccessResponse>("/api/v1/iam/register", {
      method: "POST",
      body: JSON.stringify(data),
    }),

  login: (data: LoginRequest) =>
    apiFetch<LoginResponse>("/api/v1/iam/login", {
      method: "POST",
      body: JSON.stringify(data),
    }),

  getProfile: () =>
    apiFetch<SuccessResponse<UserDTO>>("/api/v1/iam/profile"),

  updateProfile: (data: UpdateProfileRequest) =>
    apiFetch<SuccessResponse<UserDTO>>("/api/v1/iam/profile", {
      method: "PUT",
      body: JSON.stringify(data),
    }),

  introspect: () =>
    apiFetch<{ valid: boolean; user_id: string; email: string; role: string }>(
      "/api/v1/iam/introspect"
    ),
};

// ════════════════════════════════════════════════════════════════════════════
// Hardware Service API
// ════════════════════════════════════════════════════════════════════════════

export const hardwareApi = {
  // Equipment
  listEquipment: () =>
    apiFetch<SuccessResponse<Equipment[]>>("/api/v1/hardware/equipments"),

  createEquipment: (data: CreateEquipmentRequest) =>
    apiFetch<SuccessResponse<Equipment>>("/api/v1/hardware/equipments", {
      method: "POST",
      body: JSON.stringify(data),
    }),

  updateEquipment: (id: string, data: UpdateEquipmentRequest) =>
    apiFetch<SuccessResponse<Equipment>>(`/api/v1/hardware/equipments/${id}`, {
      method: "PUT",
      body: JSON.stringify(data),
    }),

  deleteEquipment: (id: string) =>
    apiFetch<SuccessResponse>(`/api/v1/hardware/equipments/${id}`, {
      method: "DELETE",
    }),

  controlEquipment: (id: string, command: ControlCommand) =>
    apiFetch<SuccessResponse>(`/api/v1/hardware/control/${id}`, {
      method: "POST",
      body: JSON.stringify(command),
    }),

  // Sensors
  listSensors: () =>
    apiFetch<SuccessResponse<Sensor[]>>("/api/v1/hardware/sensors"),

  createSensor: (data: CreateSensorRequest) =>
    apiFetch<SuccessResponse<Sensor>>("/api/v1/hardware/sensors", {
      method: "POST",
      body: JSON.stringify(data),
    }),

  updateSensor: (id: string, data: UpdateSensorRequest) =>
    apiFetch<SuccessResponse<Sensor>>(`/api/v1/hardware/sensors/${id}`, {
      method: "PUT",
      body: JSON.stringify(data),
    }),

  deleteSensor: (id: string) =>
    apiFetch<SuccessResponse>(`/api/v1/hardware/sensors/${id}`, {
      method: "DELETE",
    }),

  // Parameters
  listParameters: () =>
    apiFetch<SuccessResponse<Parameter[]>>("/api/v1/hardware/parameters"),

  createParameter: (data: CreateParameterRequest) =>
    apiFetch<SuccessResponse<Parameter>>("/api/v1/hardware/parameters", {
      method: "POST",
      body: JSON.stringify(data),
    }),

  // Telemetry
  ingestTelemetry: (data: TelemetryPayload) =>
    apiFetch<SuccessResponse>("/api/v1/hardware/telemetry", {
      method: "POST",
      body: JSON.stringify(data),
    }),
};

// ════════════════════════════════════════════════════════════════════════════
// Analytics Service API
// ════════════════════════════════════════════════════════════════════════════

export const analyticsApi = {
  // Thresholds
  upsertThreshold: (data: UpsertThresholdRequest) =>
    apiFetch<SuccessResponse<Threshold>>("/api/v1/analytics/thresholds", {
      method: "POST",
      body: JSON.stringify(data),
    }),

  getThreshold: (parameterId: string) =>
    apiFetch<SuccessResponse<Threshold>>(
      `/api/v1/analytics/thresholds/${parameterId}`
    ),

  // Rules
  createRule: (data: CreateRuleRequest) =>
    apiFetch<SuccessResponse<AutomationRule>>("/api/v1/analytics/rules", {
      method: "POST",
      body: JSON.stringify(data),
    }),

  getRules: (parameterId: string) =>
    apiFetch<SuccessResponse<AutomationRule[]>>(
      `/api/v1/analytics/rules/${parameterId}`
    ),

  // Decision Table
  getDecisionSummary: () =>
    apiFetch<SuccessResponse<DecisionTableEntry[]>>(
      "/api/v1/analytics/decisions/summary"
    ),

  // Daily Summaries
  getDailySummaries: (date?: string) =>
    apiFetch<SuccessResponse<DailySummary[]>>(
      `/api/v1/analytics/summaries${date ? `?date=${date}` : ""}`
    ),

  getEquipmentAnalytics: (date?: string) =>
    apiFetch<SuccessResponse<EquipmentAnalysis[]>>(
      `/api/v1/analytics/equipment-analytics${date ? `?date=${date}` : ""}`
    ),

  // Telemetry Ingestion
  ingestTelemetry: (data: TelemetryPayload) =>
    apiFetch<SuccessResponse>("/api/v1/analytics/ingest", {
      method: "POST",
      body: JSON.stringify(data),
    }),
};

// ════════════════════════════════════════════════════════════════════════════
// Weather Service API
// ════════════════════════════════════════════════════════════════════════════

export const weatherApi = {
  getCurrentWeather: () =>
    apiFetch<SuccessResponse<WeatherCondition>>("/api/v1/weather/current"),

  getForecast: () =>
    apiFetch<SuccessResponse<WeatherForecast[]>>("/api/v1/weather/forecast"),

  getAlerts: () =>
    apiFetch<SuccessResponse<WeatherAlert[]>>("/api/v1/weather/alerts"),

  getRecommendations: () =>
    apiFetch<SuccessResponse<IrrigationRecommendation>>(
      "/api/v1/weather/recommendations"
    ),
};

// ════════════════════════════════════════════════════════════════════════════
// Notification Service API
// ════════════════════════════════════════════════════════════════════════════

export const notificationApi = {
  listNotifications: (recipient: string, options?: { limit?: number; offset?: number }) => {
    const params = new URLSearchParams({ recipient });
    if (options?.limit) params.set("limit", String(options.limit));
    if (options?.offset) params.set("offset", String(options.offset));
    return apiFetch<SuccessResponse<Notification[]>>(
      `/api/v1/notifications?${params.toString()}`
    );
  },

  getUnreadCount: (recipient: string) =>
    apiFetch<SuccessResponse<UnreadCountResponse>>(
      `/api/v1/notifications/unread-count?recipient=${encodeURIComponent(recipient)}`
    ),

  markAsRead: (id: string) =>
    apiFetch<SuccessResponse>(`/api/v1/notifications/${id}/read`, {
      method: "PUT",
    }),

  markAllAsRead: (recipient: string) =>
    apiFetch<SuccessResponse>(
      `/api/v1/notifications/read-all?recipient=${encodeURIComponent(recipient)}`,
      { method: "PUT" }
    ),
};
