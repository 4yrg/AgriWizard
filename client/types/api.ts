// ════════════════════════════════════════════════════════════════════════════
// AgriWizard API Types - Generated from Swagger/OpenAPI Specification
// ════════════════════════════════════════════════════════════════════════════

// ── Common Types ────────────────────────────────────────────────────────────

export interface ErrorResponse {
  error: string;
  message: string;
}

export interface SuccessResponse<T = unknown> {
  message: string;
  data: T;
}

export type UserRole = "Admin" | "Agromist";

// ── IAM Types ───────────────────────────────────────────────────────────────

export interface RegisterRequest {
  email: string;
  password: string;
  full_name: string;
  phone?: string;
  role?: UserRole;
}

export interface LoginRequest {
  email: string;
  password: string;
}

export interface UserDTO {
  id: string;
  email: string;
  full_name: string;
  role: UserRole;
}

export interface LoginResponse {
  token: string;
  expires_at: string;
  user: UserDTO;
}

export interface IntrospectResponse {
  valid: boolean;
  user_id: string;
  email: string;
  role: string;
  expires_at: number;
}

export interface UpdateProfileRequest {
  full_name?: string;
  phone?: string;
}

// ── Hardware Types ──────────────────────────────────────────────────────────

export type EquipmentStatus = "ON" | "OFF" | "LOCKED" | "DISABLED";

export interface CreateEquipmentRequest {
  name: string;
  supported_operations: string[];
  api_url?: string;
}

export interface Equipment {
  id: string;
  name: string;
  supported_operations: string[];
  mqtt_topic: string;
  api_url?: string;
  current_status: EquipmentStatus;
  created_at: string;
}

export interface ControlCommand {
  operation: string;
  payload?: Record<string, unknown>;
}

export interface CreateSensorRequest {
  name: string;
  parameter_ids: string[];
  api_url?: string;
  update_frequency_seconds?: number;
}

export interface Sensor {
  id: string;
  name: string;
  parameter_ids: string[];
  mqtt_topic: string;
  update_frequency_seconds: number;
  created_at: string;
}

export interface CreateParameterRequest {
  id: string;
  unit: string;
  description?: string;
}

export interface Parameter {
  id: string;
  unit: string;
  description?: string;
}

export interface TelemetryReading {
  parameter_id: string;
  value: number;
}

export interface TelemetryPayload {
  sensor_id: string;
  readings: TelemetryReading[];
  timestamp?: string;
}

// ── Analytics Types ─────────────────────────────────────────────────────────

export interface UpsertThresholdRequest {
  parameter_id: string;
  min_value?: number;
  max_value: number;
  is_enabled?: boolean;
}

export interface Threshold {
  id: string;
  parameter_id: string;
  min_value?: number;
  max_value: number;
  is_enabled: boolean;
  created_at: string;
  updated_at: string;
}

export interface CreateRuleRequest {
  threshold_id: string;
  equipment_id: string;
  low_action: string;
  high_action: string;
}

export interface AutomationRule {
  id: string;
  threshold_id: string;
  equipment_id: string;
  low_action: string;
  high_action: string;
  created_at: string;
}

export type DecisionStatus = "NORMAL" | "LOW" | "HIGH" | "NO_DATA";

export interface DecisionTableEntry {
  parameter_id: string;
  threshold: Threshold;
  rules: AutomationRule[];
  latest_value: number | null;
  status: DecisionStatus;
}

export interface DailySummary {
  id: string;
  sensor_id: string;
  date: string;
  metric_type: string;
  min_value: number;
  max_value: number;
  avg_value: number;
  sample_count: number;
  alerts_fired: number;
  rules_triggered: number;
}

// ── Weather Types ───────────────────────────────────────────────────────────

export interface WeatherLocation {
  latitude: number;
  longitude: number;
  city_name: string;
}

export interface WeatherCondition {
  location: WeatherLocation;
  temperature_celsius: number;
  humidity_percent: number;
  wind_speed_kmh: number;
  description: string;
  fetched_at: string;
}

export interface IrrigationRecommendation {
  scale: number;
  reason: string;
  current_temperature_celsius: number;
  rain_chance_percent: number;
}

export interface WeatherForecast {
  date: string;
  temperature_high: number;
  temperature_low: number;
  precipitation_chance: number;
  description: string;
}

export interface WeatherAlert {
  id: string;
  type: string;
  severity: "low" | "medium" | "high" | "extreme";
  message: string;
  starts_at: string;
  ends_at: string;
}
