"use client";

import { useRequireAuth } from "@/lib/auth/context";
import { useEquipment, useSensors } from "@/hooks/use-api";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { Badge } from "@/components/ui/badge";
import {
  Server,
  Cpu,
  Activity,
  AlertTriangle,
  CheckCircle2,
  XCircle,
} from "lucide-react";
import type { Equipment, Sensor } from "@/types/api";

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

function getStatusBadge(status: Equipment["current_status"]) {
  const styles = {
    ON: { variant: "default" as const, className: "bg-emerald-500/10 text-emerald-600 border-emerald-500/20" },
    OFF: { variant: "secondary" as const, className: "" },
    LOCKED: { variant: "outline" as const, className: "bg-amber-500/10 text-amber-600 border-amber-500/20" },
    DISABLED: { variant: "destructive" as const, className: "" },
  };

  const style = styles[status] || styles.OFF;

  return (
    <Badge variant={style.variant} className={style.className}>
      {status}
    </Badge>
  );
}

function EquipmentOverviewCard({ equipment }: { equipment: Equipment[] }) {
  const onCount = equipment.filter((e) => e.current_status === "ON").length;
  const offCount = equipment.filter((e) => e.current_status === "OFF").length;
  const issueCount = equipment.filter(
    (e) => e.current_status === "LOCKED" || e.current_status === "DISABLED"
  ).length;

  return (
    <Card className="col-span-full lg:col-span-2">
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Server className="h-5 w-5" />
          Equipment Overview
        </CardTitle>
      </CardHeader>
      <CardContent>
        <div className="flex items-center gap-6 mb-6">
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-emerald-500" />
            <span className="text-sm">{onCount} Active</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-muted" />
            <span className="text-sm">{offCount} Inactive</span>
          </div>
          {issueCount > 0 && (
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 rounded-full bg-amber-500" />
              <span className="text-sm">{issueCount} Issues</span>
            </div>
          )}
        </div>

        {equipment.length === 0 ? (
          <div className="text-center py-8 text-muted-foreground">
            <Server className="h-12 w-12 mx-auto mb-4 opacity-50" />
            <p>No equipment registered yet</p>
            <p className="text-sm">Add equipment to start monitoring</p>
          </div>
        ) : (
          <div className="space-y-3">
            {equipment.slice(0, 5).map((item) => (
              <div
                key={item.id}
                className="flex items-center justify-between p-3 rounded-lg bg-muted/50"
              >
                <div className="flex items-center gap-3">
                  <div
                    className={`p-2 rounded-lg ${
                      item.current_status === "ON"
                        ? "bg-emerald-500/10"
                        : "bg-muted"
                    }`}
                  >
                    <Cpu
                      className={`h-4 w-4 ${
                        item.current_status === "ON"
                          ? "text-emerald-600"
                          : "text-muted-foreground"
                      }`}
                    />
                  </div>
                  <div>
                    <p className="font-medium text-sm">{item.name}</p>
                    <p className="text-xs text-muted-foreground">
                      {item.supported_operations.join(", ")}
                    </p>
                  </div>
                </div>
                {getStatusBadge(item.current_status)}
              </div>
            ))}
            {equipment.length > 5 && (
              <p className="text-center text-sm text-muted-foreground pt-2">
                +{equipment.length - 5} more equipment
              </p>
            )}
          </div>
        )}
      </CardContent>
    </Card>
  );
}

function SensorOverviewCard({ sensors }: { sensors: Sensor[] }) {
  return (
    <Card className="col-span-full lg:col-span-1">
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Activity className="h-5 w-5" />
          Sensor Network
        </CardTitle>
      </CardHeader>
      <CardContent>
        {sensors.length === 0 ? (
          <div className="text-center py-8 text-muted-foreground">
            <Activity className="h-12 w-12 mx-auto mb-4 opacity-50" />
            <p>No sensors provisioned</p>
            <p className="text-sm">Add sensors to collect data</p>
          </div>
        ) : (
          <div className="space-y-3">
            {sensors.slice(0, 6).map((sensor) => (
              <div
                key={sensor.id}
                className="flex items-center justify-between p-3 rounded-lg bg-muted/50"
              >
                <div>
                  <p className="font-medium text-sm">{sensor.name}</p>
                  <p className="text-xs text-muted-foreground">
                    {sensor.parameter_ids.length} parameters
                  </p>
                </div>
                <Badge variant="outline" className="text-xs">
                  {sensor.update_frequency_seconds}s
                </Badge>
              </div>
            ))}
            {sensors.length > 6 && (
              <p className="text-center text-sm text-muted-foreground pt-2">
                +{sensors.length - 6} more sensors
              </p>
            )}
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
            <div className="space-y-3">
              {[...Array(4)].map((_, i) => (
                <Skeleton key={i} className="h-14 w-full" />
              ))}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

export default function AdminDashboard() {
  const { isLoading: authLoading } = useRequireAuth("Admin");
  const { data: equipment, isLoading: equipmentLoading } = useEquipment();
  const { data: sensors, isLoading: sensorsLoading } = useSensors();

  const isLoading = authLoading || equipmentLoading || sensorsLoading;

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

  const equipmentList = equipment || [];
  const sensorList = sensors || [];

  const activeEquipment = equipmentList.filter(
    (e) => e.current_status === "ON"
  ).length;
  const totalParameters = sensorList.reduce(
    (acc, s) => acc + s.parameter_ids.length,
    0
  );
  const issueCount = equipmentList.filter(
    (e) => e.current_status === "LOCKED" || e.current_status === "DISABLED"
  ).length;

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-balance">Hardware Dashboard</h1>
        <p className="text-muted-foreground">
          Monitor and manage your greenhouse hardware infrastructure
        </p>
      </div>

      <div className="space-y-6">
        {/* Stats Grid */}
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
          <StatsCard
            title="Total Equipment"
            value={equipmentList.length}
            description="Registered devices"
            icon={Server}
          />
          <StatsCard
            title="Active Equipment"
            value={activeEquipment}
            description="Currently running"
            icon={CheckCircle2}
            variant="success"
          />
          <StatsCard
            title="Sensors"
            value={sensorList.length}
            description={`${totalParameters} parameters monitored`}
            icon={Activity}
          />
          <StatsCard
            title="Issues"
            value={issueCount}
            description={issueCount > 0 ? "Require attention" : "All systems normal"}
            icon={issueCount > 0 ? AlertTriangle : CheckCircle2}
            variant={issueCount > 0 ? "warning" : "success"}
          />
        </div>

        {/* Overview Cards */}
        <div className="grid gap-6 lg:grid-cols-3">
          <EquipmentOverviewCard equipment={equipmentList} />
          <SensorOverviewCard sensors={sensorList} />
        </div>
      </div>
    </div>
  );
}
