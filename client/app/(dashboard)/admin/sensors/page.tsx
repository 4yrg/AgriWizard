"use client";

import { useState } from "react";
import { useRequireAuth } from "@/lib/auth/context";
import { useSensors, useParameters } from "@/hooks/use-api";
import { hardwareApi, ApiError } from "@/lib/api/client";
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
import { Field, FieldGroup, FieldLabel } from "@/components/ui/field";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Plus, Activity, Gauge, Clock } from "lucide-react";
import type { Sensor, Parameter } from "@/types/api";
import { toast } from "sonner";

function AddSensorDialog({ parameters }: { parameters: Parameter[] }) {
  const [open, setOpen] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [name, setName] = useState("");
  const [parameterIds, setParameterIds] = useState("");
  const [updateFrequency, setUpdateFrequency] = useState("60");
  const [apiUrl, setApiUrl] = useState("");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);

    try {
      await hardwareApi.createSensor({
        name,
        parameter_ids: parameterIds.split(",").map((s) => s.trim()),
        update_frequency_seconds: parseInt(updateFrequency),
        api_url: apiUrl || undefined,
      });

      toast.success("Sensor provisioned", {
        description: `${name} has been registered successfully.`,
      });

      mutate("sensors");
      setOpen(false);
      setName("");
      setParameterIds("");
      setUpdateFrequency("60");
      setApiUrl("");
    } catch (err) {
      if (err instanceof ApiError) {
        toast.error("Failed to provision sensor", {
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
          Add Sensor
        </Button>
      </DialogTrigger>
      <DialogContent>
        <form onSubmit={handleSubmit}>
          <DialogHeader>
            <DialogTitle>Provision New Sensor</DialogTitle>
            <DialogDescription>
              Register a new sensor device to collect telemetry data.
            </DialogDescription>
          </DialogHeader>

          <div className="py-4">
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="sensorName">Sensor Name</FieldLabel>
                <Input
                  id="sensorName"
                  placeholder="Zone A Soil Probe"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  required
                  disabled={isLoading}
                />
              </Field>

              <Field>
                <FieldLabel htmlFor="params">Parameter IDs</FieldLabel>
                <Input
                  id="params"
                  placeholder="soil_moisture_pct, soil_temp_c"
                  value={parameterIds}
                  onChange={(e) => setParameterIds(e.target.value)}
                  required
                  disabled={isLoading}
                />
                <p className="text-xs text-muted-foreground">
                  Comma-separated list of parameter IDs
                  {parameters.length > 0 && (
                    <>
                      {" "}
                      (Available:{" "}
                      {parameters.map((p) => p.id).join(", ")})
                    </>
                  )}
                </p>
              </Field>

              <Field>
                <FieldLabel htmlFor="frequency">
                  Update Frequency (seconds)
                </FieldLabel>
                <Input
                  id="frequency"
                  type="number"
                  min="1"
                  placeholder="60"
                  value={updateFrequency}
                  onChange={(e) => setUpdateFrequency(e.target.value)}
                  disabled={isLoading}
                />
              </Field>

              <Field>
                <FieldLabel htmlFor="sensorApiUrl">
                  API URL <span className="text-muted-foreground font-normal">(optional)</span>
                </FieldLabel>
                <Input
                  id="sensorApiUrl"
                  placeholder="http://192.168.1.20/data"
                  value={apiUrl}
                  onChange={(e) => setApiUrl(e.target.value)}
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
                  Creating...
                </>
              ) : (
                "Provision Sensor"
              )}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

function AddParameterDialog() {
  const [open, setOpen] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [id, setId] = useState("");
  const [unit, setUnit] = useState("");
  const [description, setDescription] = useState("");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);

    try {
      await hardwareApi.createParameter({
        id,
        unit,
        description: description || undefined,
      });

      toast.success("Parameter defined", {
        description: `${id} has been created successfully.`,
      });

      mutate("parameters");
      setOpen(false);
      setId("");
      setUnit("");
      setDescription("");
    } catch (err) {
      if (err instanceof ApiError) {
        toast.error("Failed to create parameter", {
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
        <Button variant="outline">
          <Plus className="h-4 w-4 mr-2" />
          Define Parameter
        </Button>
      </DialogTrigger>
      <DialogContent>
        <form onSubmit={handleSubmit}>
          <DialogHeader>
            <DialogTitle>Define New Parameter</DialogTitle>
            <DialogDescription>
              Create a new measurable parameter type for your sensors.
            </DialogDescription>
          </DialogHeader>

          <div className="py-4">
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="paramId">Parameter ID</FieldLabel>
                <Input
                  id="paramId"
                  placeholder="soil_moisture_pct"
                  value={id}
                  onChange={(e) => setId(e.target.value)}
                  required
                  disabled={isLoading}
                />
                <p className="text-xs text-muted-foreground">
                  Use snake_case for the ID
                </p>
              </Field>

              <Field>
                <FieldLabel htmlFor="unit">Unit</FieldLabel>
                <Input
                  id="unit"
                  placeholder="%"
                  value={unit}
                  onChange={(e) => setUnit(e.target.value)}
                  required
                  disabled={isLoading}
                />
              </Field>

              <Field>
                <FieldLabel htmlFor="desc">
                  Description <span className="text-muted-foreground font-normal">(optional)</span>
                </FieldLabel>
                <Input
                  id="desc"
                  placeholder="Volumetric soil moisture percentage"
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
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
                  Creating...
                </>
              ) : (
                "Create Parameter"
              )}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

function SensorRow({ sensor }: { sensor: Sensor }) {
  return (
    <TableRow>
      <TableCell>
        <div className="flex items-center gap-3">
          <div className="p-2 rounded-lg bg-primary/10">
            <Activity className="h-4 w-4 text-primary" />
          </div>
          <div>
            <p className="font-medium">{sensor.name}</p>
            <p className="text-xs text-muted-foreground font-mono">
              {sensor.id.slice(0, 8)}...
            </p>
          </div>
        </div>
      </TableCell>
      <TableCell>
        <div className="flex flex-wrap gap-1">
          {sensor.parameter_ids.map((param) => (
            <Badge key={param} variant="secondary" className="text-xs">
              {param}
            </Badge>
          ))}
        </div>
      </TableCell>
      <TableCell>
        <div className="flex items-center gap-1.5 text-muted-foreground">
          <Clock className="h-3.5 w-3.5" />
          <span className="text-sm">{sensor.update_frequency_seconds}s</span>
        </div>
      </TableCell>
      <TableCell>
        <code className="text-xs bg-muted px-2 py-1 rounded">
          {sensor.mqtt_topic}
        </code>
      </TableCell>
      <TableCell>
        {new Date(sensor.created_at).toLocaleDateString()}
      </TableCell>
    </TableRow>
  );
}

function ParameterRow({ parameter }: { parameter: Parameter }) {
  return (
    <TableRow>
      <TableCell>
        <div className="flex items-center gap-3">
          <div className="p-2 rounded-lg bg-secondary">
            <Gauge className="h-4 w-4 text-muted-foreground" />
          </div>
          <code className="font-medium">{parameter.id}</code>
        </div>
      </TableCell>
      <TableCell>
        <Badge variant="outline">{parameter.unit}</Badge>
      </TableCell>
      <TableCell className="text-muted-foreground">
        {parameter.description || "-"}
      </TableCell>
    </TableRow>
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

export default function SensorsPage() {
  const { isLoading: authLoading } = useRequireAuth("Admin");
  const { data: sensors, isLoading: sensorsLoading } = useSensors();
  const { data: parameters, isLoading: parametersLoading } = useParameters();

  const isLoading = authLoading || sensorsLoading || parametersLoading;

  return (
    <div className="p-6">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-balance">Sensors & Parameters</h1>
        <p className="text-muted-foreground">
          Manage sensor devices and define measurable parameters
        </p>
      </div>

      <Tabs defaultValue="sensors" className="space-y-6">
        <TabsList>
          <TabsTrigger value="sensors">
            <Activity className="h-4 w-4 mr-2" />
            Sensors
          </TabsTrigger>
          <TabsTrigger value="parameters">
            <Gauge className="h-4 w-4 mr-2" />
            Parameters
          </TabsTrigger>
        </TabsList>

        <TabsContent value="sensors">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between">
              <div>
                <CardTitle>Sensor Devices</CardTitle>
                <CardDescription>
                  All provisioned sensors collecting telemetry data
                </CardDescription>
              </div>
              <AddSensorDialog parameters={parameters || []} />
            </CardHeader>
            <CardContent>
              {isLoading ? (
                <TableSkeleton />
              ) : !sensors || sensors.length === 0 ? (
                <div className="text-center py-12">
                  <Activity className="h-12 w-12 mx-auto mb-4 text-muted-foreground/50" />
                  <h3 className="font-medium mb-1">No sensors provisioned</h3>
                  <p className="text-sm text-muted-foreground mb-4">
                    Add your first sensor to start collecting data
                  </p>
                  <AddSensorDialog parameters={parameters || []} />
                </div>
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Sensor</TableHead>
                      <TableHead>Parameters</TableHead>
                      <TableHead>Frequency</TableHead>
                      <TableHead>MQTT Topic</TableHead>
                      <TableHead>Created</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {sensors.map((sensor) => (
                      <SensorRow key={sensor.id} sensor={sensor} />
                    ))}
                  </TableBody>
                </Table>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="parameters">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between">
              <div>
                <CardTitle>Parameter Definitions</CardTitle>
                <CardDescription>
                  Measurable metric types for your sensors
                </CardDescription>
              </div>
              <AddParameterDialog />
            </CardHeader>
            <CardContent>
              {isLoading ? (
                <TableSkeleton />
              ) : !parameters || parameters.length === 0 ? (
                <div className="text-center py-12">
                  <Gauge className="h-12 w-12 mx-auto mb-4 text-muted-foreground/50" />
                  <h3 className="font-medium mb-1">No parameters defined</h3>
                  <p className="text-sm text-muted-foreground mb-4">
                    Define parameters before provisioning sensors
                  </p>
                  <AddParameterDialog />
                </div>
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Parameter ID</TableHead>
                      <TableHead>Unit</TableHead>
                      <TableHead>Description</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {parameters.map((param) => (
                      <ParameterRow key={param.id} parameter={param} />
                    ))}
                  </TableBody>
                </Table>
              )}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}
