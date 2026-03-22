"use client";

import { useState } from "react";
import { useRequireAuth } from "@/lib/auth/context";
import { useDecisionSummary, useEquipment } from "@/hooks/use-api";
import { analyticsApi, ApiError } from "@/lib/api/client";
import { mutate } from "swr";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  CardDescription,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { Spinner } from "@/components/ui/spinner";
import { Switch } from "@/components/ui/switch";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Field, FieldGroup, FieldLabel, FieldDescription } from "@/components/ui/field";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Plus,
  Thermometer,
  Zap,
  TrendingDown,
  TrendingUp,
  CheckCircle2,
  Minus,
  Settings2,
} from "lucide-react";
import type { DecisionTableEntry, DecisionStatus, Equipment } from "@/types/api";
import { toast } from "sonner";

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

function AddThresholdDialog() {
  const [open, setOpen] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [parameterId, setParameterId] = useState("");
  const [minValue, setMinValue] = useState("");
  const [maxValue, setMaxValue] = useState("");
  const [isEnabled, setIsEnabled] = useState(true);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);

    try {
      await analyticsApi.upsertThreshold({
        parameter_id: parameterId,
        min_value: minValue ? parseFloat(minValue) : undefined,
        max_value: parseFloat(maxValue),
        is_enabled: isEnabled,
      });

      toast.success("Threshold saved", {
        description: `Threshold for ${parameterId} has been configured.`,
      });

      mutate("decisions");
      setOpen(false);
      setParameterId("");
      setMinValue("");
      setMaxValue("");
      setIsEnabled(true);
    } catch (err) {
      if (err instanceof ApiError) {
        toast.error("Failed to save threshold", {
          description: err.message,
        });
      }
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button>
          <Plus className="h-4 w-4 mr-2" />
          Add Threshold
        </Button>
      </DialogTrigger>
      <DialogContent>
        <form onSubmit={handleSubmit}>
          <DialogHeader>
            <DialogTitle>Configure Threshold</DialogTitle>
            <DialogDescription>
              Set alert thresholds for a sensor parameter.
            </DialogDescription>
          </DialogHeader>

          <div className="py-4">
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="paramId">Parameter ID</FieldLabel>
                <Input
                  id="paramId"
                  placeholder="soil_moisture_pct"
                  value={parameterId}
                  onChange={(e) => setParameterId(e.target.value)}
                  required
                  disabled={isLoading}
                />
              </Field>

              <div className="grid grid-cols-2 gap-4">
                <Field>
                  <FieldLabel htmlFor="minVal">
                    Minimum Value <span className="text-muted-foreground font-normal">(optional)</span>
                  </FieldLabel>
                  <Input
                    id="minVal"
                    type="number"
                    step="any"
                    placeholder="30"
                    value={minValue}
                    onChange={(e) => setMinValue(e.target.value)}
                    disabled={isLoading}
                  />
                </Field>

                <Field>
                  <FieldLabel htmlFor="maxVal">Maximum Value</FieldLabel>
                  <Input
                    id="maxVal"
                    type="number"
                    step="any"
                    placeholder="70"
                    value={maxValue}
                    onChange={(e) => setMaxValue(e.target.value)}
                    required
                    disabled={isLoading}
                  />
                </Field>
              </div>

              <Field orientation="horizontal">
                <FieldLabel htmlFor="enabled">Enable Threshold</FieldLabel>
                <Switch
                  id="enabled"
                  checked={isEnabled}
                  onCheckedChange={setIsEnabled}
                  disabled={isLoading}
                />
              </Field>
            </FieldGroup>
          </div>

          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => setOpen(false)}
              disabled={isLoading}
            >
              Cancel
            </Button>
            <Button type="submit" disabled={isLoading}>
              {isLoading ? (
                <>
                  <Spinner className="mr-2" />
                  Saving...
                </>
              ) : (
                "Save Threshold"
              )}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

function AddRuleDialog({ entry, equipment }: { entry: DecisionTableEntry; equipment: Equipment[] }) {
  const [open, setOpen] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [equipmentId, setEquipmentId] = useState("");
  const [lowAction, setLowAction] = useState("");
  const [highAction, setHighAction] = useState("");

  const selectedEquipment = equipment.find((e) => e.id === equipmentId);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);

    try {
      await analyticsApi.createRule({
        threshold_id: entry.threshold.id,
        equipment_id: equipmentId,
        low_action: lowAction,
        high_action: highAction,
      });

      toast.success("Rule created", {
        description: "Automation rule has been configured.",
      });

      mutate("decisions");
      setOpen(false);
      setEquipmentId("");
      setLowAction("");
      setHighAction("");
    } catch (err) {
      if (err instanceof ApiError) {
        toast.error("Failed to create rule", {
          description: err.message,
        });
      }
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button variant="outline" size="sm">
          <Zap className="h-3.5 w-3.5 mr-1.5" />
          Add Rule
        </Button>
      </DialogTrigger>
      <DialogContent>
        <form onSubmit={handleSubmit}>
          <DialogHeader>
            <DialogTitle>Create Automation Rule</DialogTitle>
            <DialogDescription>
              Link this threshold to equipment for automatic control.
            </DialogDescription>
          </DialogHeader>

          <div className="py-4">
            <FieldGroup>
              <div className="p-3 rounded-lg bg-muted text-sm">
                <p className="font-medium">{entry.parameter_id}</p>
                <p className="text-muted-foreground">
                  Range: {entry.threshold.min_value ?? "-"} -{" "}
                  {entry.threshold.max_value}
                </p>
              </div>

              <Field>
                <FieldLabel htmlFor="equipment">Target Equipment</FieldLabel>
                <Select value={equipmentId} onValueChange={setEquipmentId}>
                  <SelectTrigger id="equipment">
                    <SelectValue placeholder="Select equipment" />
                  </SelectTrigger>
                  <SelectContent>
                    {equipment.map((e) => (
                      <SelectItem key={e.id} value={e.id}>
                        {e.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </Field>

              {selectedEquipment && (
                <>
                  <Field>
                    <FieldLabel htmlFor="lowAction">Low Action</FieldLabel>
                    <Select value={lowAction} onValueChange={setLowAction}>
                      <SelectTrigger id="lowAction">
                        <SelectValue placeholder="Action when value is low" />
                      </SelectTrigger>
                      <SelectContent>
                        {selectedEquipment.supported_operations.map((op) => (
                          <SelectItem key={op} value={op}>
                            {op}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                    <FieldDescription>
                      Command to send when value drops below minimum
                    </FieldDescription>
                  </Field>

                  <Field>
                    <FieldLabel htmlFor="highAction">High Action</FieldLabel>
                    <Select value={highAction} onValueChange={setHighAction}>
                      <SelectTrigger id="highAction">
                        <SelectValue placeholder="Action when value is high" />
                      </SelectTrigger>
                      <SelectContent>
                        {selectedEquipment.supported_operations.map((op) => (
                          <SelectItem key={op} value={op}>
                            {op}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                    <FieldDescription>
                      Command to send when value exceeds maximum
                    </FieldDescription>
                  </Field>
                </>
              )}
            </FieldGroup>
          </div>

          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => setOpen(false)}
              disabled={isLoading}
            >
              Cancel
            </Button>
            <Button
              type="submit"
              disabled={isLoading || !equipmentId || !lowAction || !highAction}
            >
              {isLoading ? (
                <>
                  <Spinner className="mr-2" />
                  Creating...
                </>
              ) : (
                "Create Rule"
              )}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

function ThresholdRow({
  entry,
  equipment,
}: {
  entry: DecisionTableEntry;
  equipment: Equipment[];
}) {
  const statusInfo = getStatusInfo(entry.status);
  const StatusIcon = statusInfo.icon;

  return (
    <TableRow>
      <TableCell>
        <div className="flex items-center gap-3">
          <div className={`p-2 rounded-lg ${statusInfo.bg}`}>
            <StatusIcon className={`h-4 w-4 ${statusInfo.color}`} />
          </div>
          <div>
            <p className="font-medium">{entry.parameter_id}</p>
            <p className="text-xs text-muted-foreground">
              {entry.threshold.id.slice(0, 8)}...
            </p>
          </div>
        </div>
      </TableCell>
      <TableCell>
        <div className="flex items-center gap-2">
          <span className="text-muted-foreground">
            {entry.threshold.min_value ?? "-"}
          </span>
          <span className="text-muted-foreground">to</span>
          <span>{entry.threshold.max_value}</span>
        </div>
      </TableCell>
      <TableCell>
        <span className="font-medium">
          {entry.latest_value !== null ? entry.latest_value.toFixed(2) : "-"}
        </span>
      </TableCell>
      <TableCell>
        <Badge
          variant="outline"
          className={`${statusInfo.bg} ${statusInfo.color} border-0`}
        >
          {statusInfo.label}
        </Badge>
      </TableCell>
      <TableCell>
        <div className="flex items-center gap-2">
          <Badge variant="secondary">{entry.rules.length} rules</Badge>
          <AddRuleDialog entry={entry} equipment={equipment} />
        </div>
      </TableCell>
      <TableCell>
        <Badge variant={entry.threshold.is_enabled ? "default" : "secondary"}>
          {entry.threshold.is_enabled ? "Active" : "Disabled"}
        </Badge>
      </TableCell>
    </TableRow>
  );
}

function RulesCard({ decisions }: { decisions: DecisionTableEntry[] }) {
  const allRules = decisions.flatMap((d) =>
    d.rules.map((r) => ({ ...r, parameter_id: d.parameter_id }))
  );

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Zap className="h-5 w-5" />
          Automation Rules
        </CardTitle>
        <CardDescription>
          Rules that automatically control equipment based on thresholds
        </CardDescription>
      </CardHeader>
      <CardContent>
        {allRules.length === 0 ? (
          <div className="text-center py-8 text-muted-foreground">
            <Zap className="h-12 w-12 mx-auto mb-4 opacity-50" />
            <p>No automation rules configured</p>
            <p className="text-sm">
              Add rules to thresholds for automatic control
            </p>
          </div>
        ) : (
          <div className="space-y-3">
            {allRules.map((rule) => (
              <div
                key={rule.id}
                className="flex items-center justify-between p-3 rounded-lg bg-muted/50"
              >
                <div>
                  <p className="font-medium text-sm">{rule.parameter_id}</p>
                  <p className="text-xs text-muted-foreground">
                    Low: {rule.low_action} | High: {rule.high_action}
                  </p>
                </div>
                <Badge variant="outline" className="text-xs">
                  {rule.equipment_id.slice(0, 8)}...
                </Badge>
              </div>
            ))}
          </div>
        )}
      </CardContent>
    </Card>
  );
}

function TableSkeleton() {
  return (
    <div className="space-y-3">
      {[...Array(5)].map((_, i) => (
        <Skeleton key={i} className="h-16 w-full" />
      ))}
    </div>
  );
}

export default function ThresholdsPage() {
  const { isLoading: authLoading } = useRequireAuth("Agromist");
  const { data: decisions, isLoading: decisionsLoading } = useDecisionSummary();
  const { data: equipment, isLoading: equipmentLoading } = useEquipment();

  const isLoading = authLoading || decisionsLoading || equipmentLoading;

  return (
    <div className="p-6">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-balance">Threshold Management</h1>
          <p className="text-muted-foreground">
            Configure alert thresholds and automation rules
          </p>
        </div>
        <AddThresholdDialog />
      </div>

      <Tabs defaultValue="thresholds" className="space-y-6">
        <TabsList>
          <TabsTrigger value="thresholds">
            <Thermometer className="h-4 w-4 mr-2" />
            Thresholds
          </TabsTrigger>
          <TabsTrigger value="rules">
            <Zap className="h-4 w-4 mr-2" />
            Rules
          </TabsTrigger>
        </TabsList>

        <TabsContent value="thresholds">
          <Card>
            <CardHeader>
              <CardTitle>Parameter Thresholds</CardTitle>
              <CardDescription>
                Safe operating ranges for sensor parameters
              </CardDescription>
            </CardHeader>
            <CardContent>
              {isLoading ? (
                <TableSkeleton />
              ) : !decisions || decisions.length === 0 ? (
                <div className="text-center py-12">
                  <Settings2 className="h-12 w-12 mx-auto mb-4 text-muted-foreground/50" />
                  <h3 className="font-medium mb-1">No thresholds configured</h3>
                  <p className="text-sm text-muted-foreground mb-4">
                    Add thresholds to monitor your sensor parameters
                  </p>
                  <AddThresholdDialog />
                </div>
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Parameter</TableHead>
                      <TableHead>Range</TableHead>
                      <TableHead>Current</TableHead>
                      <TableHead>Status</TableHead>
                      <TableHead>Automation</TableHead>
                      <TableHead>State</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {decisions.map((entry) => (
                      <ThresholdRow
                        key={entry.parameter_id}
                        entry={entry}
                        equipment={equipment || []}
                      />
                    ))}
                  </TableBody>
                </Table>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="rules">
          <RulesCard decisions={decisions || []} />
        </TabsContent>
      </Tabs>
    </div>
  );
}
