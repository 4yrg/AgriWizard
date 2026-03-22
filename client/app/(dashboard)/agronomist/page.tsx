"use client";

import { useRequireAuth } from "@/lib/auth/context";
import {
  useDecisionSummary,
  useCurrentWeather,
  useIrrigationRecommendation,
  useWeatherAlerts,
} from "@/hooks/use-api";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Cloud,
  Droplets,
  Thermometer,
  Wind,
  AlertTriangle,
  CheckCircle2,
  TrendingDown,
  TrendingUp,
  Minus,
  Sun,
} from "lucide-react";
import type { DecisionTableEntry, DecisionStatus } from "@/types/api";

function StatsCard({
  title,
  value,
  description,
  icon: Icon,
  variant = "default",
}: {
  title: string;
  value: string | number;
  description: string;
  icon: React.ComponentType<{ className?: string }>;
  variant?: "default" | "success" | "warning" | "danger";
}) {
  const variantStyles = {
    default: "bg-primary/10 text-primary",
    success: "bg-emerald-500/10 text-emerald-600",
    warning: "bg-amber-500/10 text-amber-600",
    danger: "bg-destructive/10 text-destructive",
  };

  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between pb-2">
        <CardTitle className="text-sm font-medium text-muted-foreground">
          {title}
        </CardTitle>
        <div className={`p-2 rounded-lg ${variantStyles[variant]}`}>
          <Icon className="h-4 w-4" />
        </div>
      </CardHeader>
      <CardContent>
        <div className="text-2xl font-bold">{value}</div>
        <p className="text-xs text-muted-foreground mt-1">{description}</p>
      </CardContent>
    </Card>
  );
}

function getStatusInfo(status: DecisionStatus) {
  const statusMap = {
    NORMAL: {
      icon: CheckCircle2,
      color: "text-emerald-600",
      bg: "bg-emerald-500/10",
      label: "Normal",
    },
    LOW: {
      icon: TrendingDown,
      color: "text-blue-600",
      bg: "bg-blue-500/10",
      label: "Low",
    },
    HIGH: {
      icon: TrendingUp,
      color: "text-amber-600",
      bg: "bg-amber-500/10",
      label: "High",
    },
    NO_DATA: {
      icon: Minus,
      color: "text-muted-foreground",
      bg: "bg-muted",
      label: "No Data",
    },
  };

  return statusMap[status] || statusMap.NO_DATA;
}

function WeatherCard() {
  const { data: weather, isLoading } = useCurrentWeather();
  const { data: recommendation } = useIrrigationRecommendation();
  const { data: alerts } = useWeatherAlerts();

  if (isLoading) {
    return (
      <Card>
        <CardHeader>
          <Skeleton className="h-6 w-32" />
        </CardHeader>
        <CardContent>
          <Skeleton className="h-24 w-full" />
        </CardContent>
      </Card>
    );
  }

  if (!weather) {
    return null;
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Sun className="h-5 w-5" />
          Current Weather
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        {alerts && alerts.length > 0 && (
          <div className="p-3 rounded-lg bg-destructive/10 border border-destructive/20">
            <div className="flex items-center gap-2 text-destructive font-medium text-sm">
              <AlertTriangle className="h-4 w-4" />
              Weather Alert
            </div>
            <p className="text-sm mt-1">{alerts[0].message}</p>
          </div>
        )}

        <div className="flex items-center justify-between">
          <div>
            <p className="text-3xl font-bold">
              {Math.round(weather.temperature_celsius)}°C
            </p>
            <p className="text-muted-foreground capitalize">
              {weather.description}
            </p>
          </div>
          <Cloud className="h-12 w-12 text-muted-foreground/50" />
        </div>

        <div className="grid grid-cols-2 gap-4 pt-2">
          <div className="flex items-center gap-2">
            <Droplets className="h-4 w-4 text-blue-500" />
            <div>
              <p className="text-sm font-medium">
                {weather.humidity_percent}%
              </p>
              <p className="text-xs text-muted-foreground">Humidity</p>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <Wind className="h-4 w-4 text-muted-foreground" />
            <div>
              <p className="text-sm font-medium">
                {weather.wind_speed_kmh} km/h
              </p>
              <p className="text-xs text-muted-foreground">Wind</p>
            </div>
          </div>
        </div>

        {recommendation && (
          <div className="pt-4 border-t">
            <div className="flex items-center justify-between mb-2">
              <p className="text-sm font-medium">Irrigation Recommendation</p>
              <Badge
                variant={recommendation.scale < 1 ? "secondary" : "default"}
                className={
                  recommendation.scale > 1
                    ? "bg-blue-500/10 text-blue-600 border-blue-500/20"
                    : ""
                }
              >
                {recommendation.scale.toFixed(1)}x
              </Badge>
            </div>
            <p className="text-xs text-muted-foreground">
              {recommendation.reason}
            </p>
          </div>
        )}
      </CardContent>
    </Card>
  );
}

function DecisionSummaryCard({
  decisions,
}: {
  decisions: DecisionTableEntry[];
}) {
  const normalCount = decisions.filter((d) => d.status === "NORMAL").length;
  const issueCount = decisions.filter(
    (d) => d.status === "LOW" || d.status === "HIGH"
  ).length;

  return (
    <Card className="col-span-full lg:col-span-2">
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Thermometer className="h-5 w-5" />
          System Status
        </CardTitle>
      </CardHeader>
      <CardContent>
        <div className="flex items-center gap-6 mb-6">
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-emerald-500" />
            <span className="text-sm">{normalCount} Normal</span>
          </div>
          {issueCount > 0 && (
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 rounded-full bg-amber-500" />
              <span className="text-sm">{issueCount} Alerts</span>
            </div>
          )}
        </div>

        {decisions.length === 0 ? (
          <div className="text-center py-8 text-muted-foreground">
            <Thermometer className="h-12 w-12 mx-auto mb-4 opacity-50" />
            <p>No thresholds configured</p>
            <p className="text-sm">Set up thresholds to monitor parameters</p>
          </div>
        ) : (
          <div className="space-y-3">
            {decisions.map((entry) => {
              const statusInfo = getStatusInfo(entry.status);
              const StatusIcon = statusInfo.icon;

              return (
                <div
                  key={entry.parameter_id}
                  className="flex items-center justify-between p-3 rounded-lg bg-muted/50"
                >
                  <div className="flex items-center gap-3">
                    <div className={`p-2 rounded-lg ${statusInfo.bg}`}>
                      <StatusIcon className={`h-4 w-4 ${statusInfo.color}`} />
                    </div>
                    <div>
                      <p className="font-medium text-sm">
                        {entry.parameter_id}
                      </p>
                      <p className="text-xs text-muted-foreground">
                        Range: {entry.threshold.min_value ?? "-"} -{" "}
                        {entry.threshold.max_value}
                      </p>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="font-medium">
                      {entry.latest_value !== null
                        ? entry.latest_value.toFixed(1)
                        : "-"}
                    </p>
                    <Badge
                      variant="outline"
                      className={`${statusInfo.bg} ${statusInfo.color} border-0 text-xs`}
                    >
                      {statusInfo.label}
                    </Badge>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </CardContent>
    </Card>
  );
}

function DashboardSkeleton() {
  return (
    <div className="space-y-6">
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        {[...Array(4)].map((_, i) => (
          <Card key={i}>
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <Skeleton className="h-4 w-24" />
              <Skeleton className="h-8 w-8 rounded-lg" />
            </CardHeader>
            <CardContent>
              <Skeleton className="h-8 w-16 mb-1" />
              <Skeleton className="h-3 w-32" />
            </CardContent>
          </Card>
        ))}
      </div>
      <div className="grid gap-6 lg:grid-cols-3">
        <Card className="col-span-full lg:col-span-2">
          <CardHeader>
            <Skeleton className="h-6 w-40" />
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {[...Array(4)].map((_, i) => (
                <Skeleton key={i} className="h-16 w-full" />
              ))}
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <Skeleton className="h-6 w-32" />
          </CardHeader>
          <CardContent>
            <Skeleton className="h-32 w-full" />
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

export default function AgronomistDashboard() {
  const { isLoading: authLoading } = useRequireAuth("Agromist");
  const { data: decisions, isLoading: decisionsLoading } = useDecisionSummary();

  const isLoading = authLoading || decisionsLoading;

  if (isLoading) {
    return (
      <div className="p-6">
        <div className="mb-6">
          <Skeleton className="h-8 w-48 mb-2" />
          <Skeleton className="h-4 w-64" />
        </div>
        <DashboardSkeleton />
      </div>
    );
  }

  const decisionList = decisions || [];
  const normalCount = decisionList.filter((d) => d.status === "NORMAL").length;
  const alertCount = decisionList.filter(
    (d) => d.status === "LOW" || d.status === "HIGH"
  ).length;
  const rulesCount = decisionList.reduce(
    (acc, d) => acc + d.rules.length,
    0
  );

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-balance">Analytics Dashboard</h1>
        <p className="text-muted-foreground">
          Monitor thresholds, automation rules, and environmental conditions
        </p>
      </div>

      <div className="space-y-6">
        {/* Stats Grid */}
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
          <StatsCard
            title="Thresholds"
            value={decisionList.length}
            description="Monitored parameters"
            icon={Thermometer}
          />
          <StatsCard
            title="Normal"
            value={normalCount}
            description="Within safe range"
            icon={CheckCircle2}
            variant="success"
          />
          <StatsCard
            title="Alerts"
            value={alertCount}
            description={alertCount > 0 ? "Require attention" : "All clear"}
            icon={AlertTriangle}
            variant={alertCount > 0 ? "warning" : "success"}
          />
          <StatsCard
            title="Automation Rules"
            value={rulesCount}
            description="Active automations"
            icon={TrendingUp}
          />
        </div>

        {/* Overview Cards */}
        <div className="grid gap-6 lg:grid-cols-3">
          <DecisionSummaryCard decisions={decisionList} />
          <WeatherCard />
        </div>
      </div>
    </div>
  );
}
