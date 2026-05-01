"use client";

import { useRequireAuth } from "@/lib/auth/context";
import { useEquipmentAnalytics, useEquipment } from "@/hooks/use-api";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { 
  Activity, 
  Zap, 
  BarChart3, 
  Settings2, 
  Clock, 
  AlertCircle,
  Cpu
} from "lucide-react";
import { 
  BarChart, 
  Bar, 
  XAxis, 
  YAxis, 
  CartesianGrid, 
  Tooltip, 
  ResponsiveContainer,
  Cell,
  LineChart,
  Line,
  AreaChart,
  Area
} from "recharts";
import { Badge } from "@/components/ui/badge";

export default function EquipmentAnalyticsPage() {
  const { isLoading: authLoading } = useRequireAuth("Agromist");
  const { data: analytics, isLoading: analyticsLoading } = useEquipmentAnalytics();
  const { data: equipmentList, isLoading: equipmentLoading } = useEquipment();

  const isLoading = authLoading || analyticsLoading || equipmentLoading;

  if (isLoading) {
    return (
      <div className="p-8 space-y-8 animate-pulse">
        <div className="space-y-2">
          <Skeleton className="h-10 w-64 bg-primary/5" />
          <Skeleton className="h-4 w-96 bg-primary/5" />
        </div>
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
          {[...Array(3)].map((_, i) => (
            <Skeleton key={i} className="h-[350px] rounded-3xl bg-primary/5" />
          ))}
        </div>
      </div>
    );
  }

  const enrichedAnalytics = analytics?.map(a => {
    const equip = equipmentList?.find(e => e.id === a.equipment_id);
    return {
      ...a,
      name: equip?.name || a.equipment_id,
      serial: equip?.serial,
    };
  }) || [];

  // Sort by usage count
  const sortedByUsage = [...enrichedAnalytics].sort((a, b) => b.usage_count - a.usage_count);

  return (
    <div className="p-8 space-y-10 min-h-screen">
      {/* Header Section with Glassmorphism */}
      <div className="relative group">
        <div className="absolute -inset-1 bg-gradient-to-r from-primary/20 to-emerald-500/20 rounded-2xl blur opacity-25 group-hover:opacity-40 transition duration-1000 group-hover:duration-200"></div>
        <div className="relative space-y-2 px-1">
          <h1 className="text-4xl font-extrabold tracking-tight bg-gradient-to-br from-foreground to-foreground/60 bg-clip-text text-transparent">
            Equipment Intelligence
          </h1>
          <p className="text-muted-foreground text-lg font-medium flex items-center gap-2">
            <Activity className="h-5 w-5 text-primary" />
            Performance metrics and predictive health analysis for greenhouse hardware.
          </p>
        </div>
      </div>

      {/* Main Grid */}
      <div className="grid gap-8 lg:grid-cols-12">
        
        {/* Usage Overview Chart */}
        <Card className="lg:col-span-8 border-none bg-white/40 dark:bg-zinc-900/40 backdrop-blur-xl shadow-2xl shadow-primary/5 rounded-3xl overflow-hidden ring-1 ring-white/20">
          <CardHeader className="pb-2">
            <div className="flex items-center justify-between">
              <div>
                <CardTitle className="text-xl font-bold">Activation Pulse</CardTitle>
                <CardDescription>Frequency of equipment activations across the facility</CardDescription>
              </div>
              <div className="p-3 bg-primary/10 rounded-2xl">
                <BarChart3 className="h-6 w-6 text-primary" />
              </div>
            </div>
          </CardHeader>
          <CardContent className="h-[350px] pt-4">
            {enrichedAnalytics.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={enrichedAnalytics} margin={{ top: 20, right: 30, left: 0, bottom: 0 }}>
                  <defs>
                    <linearGradient id="usageGradient" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor="hsl(var(--primary))" stopOpacity={0.8}/>
                      <stop offset="100%" stopColor="hsl(var(--primary))" stopOpacity={0.2}/>
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="rgba(0,0,0,0.05)" />
                  <XAxis 
                    dataKey="name" 
                    axisLine={false} 
                    tickLine={false} 
                    tick={{ fill: 'currentColor', opacity: 0.5, fontSize: 12 }} 
                  />
                  <YAxis 
                    axisLine={false} 
                    tickLine={false} 
                    tick={{ fill: 'currentColor', opacity: 0.5, fontSize: 12 }} 
                  />
                  <Tooltip 
                    contentStyle={{ 
                      backgroundColor: 'rgba(255,255,255,0.8)', 
                      backdropFilter: 'blur(10px)',
                      borderRadius: '16px',
                      border: '1px solid rgba(0,0,0,0.05)',
                      boxShadow: '0 10px 15px -3px rgba(0,0,0,0.1)'
                    }}
                  />
                  <Bar 
                    dataKey="usage_count" 
                    radius={[10, 10, 0, 0]} 
                    fill="url(#usageGradient)"
                    animationDuration={1500}
                  />
                </BarChart>
              </ResponsiveContainer>
            ) : (
              <div className="flex flex-col items-center justify-center h-full text-muted-foreground gap-4">
                <div className="p-4 bg-muted/50 rounded-full">
                  <Zap className="h-10 w-10 opacity-20" />
                </div>
                <p>No telemetry data available for the selected period.</p>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Efficiency Sidebar */}
        <Card className="lg:col-span-4 border-none bg-gradient-to-br from-primary/5 to-emerald-500/5 backdrop-blur-xl shadow-2xl rounded-3xl ring-1 ring-white/20">
          <CardHeader>
            <CardTitle className="text-xl font-bold flex items-center gap-2">
              <Zap className="h-5 w-5 text-emerald-500" />
              Efficiency Scores
            </CardTitle>
            <CardDescription>Estimated operational effectiveness</CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            {enrichedAnalytics.length > 0 ? (
              enrichedAnalytics.map((item, idx) => (
                <div key={item.id} className="space-y-2">
                  <div className="flex justify-between items-center text-sm font-semibold">
                    <span className="text-foreground/70">{item.name}</span>
                    <span className={item.efficiency_score > 80 ? "text-emerald-500" : "text-amber-500"}>
                      {item.efficiency_score.toFixed(1)}%
                    </span>
                  </div>
                  <div className="h-2 w-full bg-black/5 dark:bg-white/5 rounded-full overflow-hidden">
                    <div 
                      className="h-full bg-gradient-to-r from-emerald-500 to-primary transition-all duration-1000 ease-out" 
                      style={{ width: `${item.efficiency_score}%`, transitionDelay: `${idx * 100}ms` }}
                    />
                  </div>
                </div>
              ))
            ) : (
              <p className="text-center text-muted-foreground py-10">Awaiting more data...</p>
            )}
          </CardContent>
        </Card>

        {/* Detailed Logs Section */}
        <div className="lg:col-span-12">
          <h2 className="text-2xl font-bold mb-6 flex items-center gap-3">
            <Clock className="h-6 w-6 text-primary" />
            Recent Device Activity
          </h2>
          <div className="grid gap-6 md:grid-cols-2 xl:grid-cols-3">
            {sortedByUsage.map((item) => (
              <Card key={item.id} className="group border-none bg-white/30 dark:bg-zinc-900/30 backdrop-blur-lg hover:bg-white/50 dark:hover:bg-zinc-800/50 transition-all duration-300 rounded-3xl ring-1 ring-white/10 hover:ring-primary/20">
                <CardContent className="p-6 space-y-4">
                  <div className="flex justify-between items-start">
                    <div className="space-y-1">
                      <div className="flex items-center gap-2">
                        <Cpu className="h-4 w-4 text-primary opacity-60" />
                        <span className="text-xs font-bold tracking-widest text-muted-foreground uppercase">{item.serial}</span>
                      </div>
                      <h3 className="text-lg font-bold group-hover:text-primary transition-colors">{item.name}</h3>
                    </div>
                    <Badge variant="outline" className="rounded-xl px-3 py-1 bg-primary/5 border-primary/20 text-primary font-bold">
                      {item.usage_count} Activations
                    </Badge>
                  </div>

                  <div className="flex items-center gap-4 py-2 border-y border-white/10">
                    <div className="flex-1 space-y-1">
                      <p className="text-[10px] text-muted-foreground font-bold uppercase tracking-wider">Last Action</p>
                      <p className="text-sm font-medium">{item.last_action || 'N/A'}</p>
                    </div>
                    <div className="w-px h-8 bg-white/10" />
                    <div className="flex-1 space-y-1">
                      <p className="text-[10px] text-muted-foreground font-bold uppercase tracking-wider">Last Sync</p>
                      <p className="text-sm font-medium">{new Date(item.updated_at).toLocaleTimeString()}</p>
                    </div>
                  </div>

                  <div className="pt-2 flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <div className={`h-2 w-2 rounded-full ${item.usage_count > 0 ? 'bg-emerald-500 animate-pulse' : 'bg-muted'}`} />
                      <span className="text-xs font-semibold text-muted-foreground">System Online</span>
                    </div>
                    <button className="text-xs font-bold text-primary hover:underline underline-offset-4">View History</button>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        </div>

      </div>
    </div>
  );
}
