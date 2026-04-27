"use client";

import { useState } from "react";
import { useRequireAuth } from "@/lib/auth/context";
import { useEquipment } from "@/hooks/use-api";
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
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Field, FieldGroup, FieldLabel } from "@/components/ui/field";
import {
  Plus,
  Power,
  PowerOff,
  Server,
  MoreHorizontal,
  Zap,
  Pencil,
  Trash2,
} from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import type { Equipment, EquipmentStatus } from "@/types/api";
import { toast } from "sonner";

function getStatusBadge(status: EquipmentStatus) {
  const styles: Record<EquipmentStatus, { className: string; icon: React.ReactNode }> = {
    ON: {
      className: "bg-emerald-500/10 text-emerald-600 border-emerald-500/20",
      icon: <Power className="h-3 w-3" />,
    },
    OFF: {
      className: "bg-muted text-muted-foreground",
      icon: <PowerOff className="h-3 w-3" />,
    },
    LOCKED: {
      className: "bg-amber-500/10 text-amber-600 border-amber-500/20",
      icon: null,
    },
    DISABLED: {
      className: "bg-destructive/10 text-destructive border-destructive/20",
      icon: null,
    },
  };

  const style = styles[status];

  return (
    <Badge variant="outline" className={style.className}>
      {style.icon}
      {status}
    </Badge>
  );
}

function AddEquipmentDialog() {
  const [open, setOpen] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [serial, setSerial] = useState("");
  const [name, setName] = useState("");
  const [operations, setOperations] = useState("");
  const [apiUrl, setApiUrl] = useState("");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);

    try {
      await hardwareApi.createEquipment({
        serial,
        name,
        supported_operations: operations.split(",").map((s) => s.trim()),
        api_url: apiUrl || undefined,
      });

      toast.success("Equipment created", {
        description: `${name} has been registered successfully.`,
      });

      mutate("equipment");
      setOpen(false);
      setSerial("");
      setName("");
      setOperations("");
      setApiUrl("");
    } catch (err) {
      if (err instanceof ApiError) {
        toast.error("Failed to create equipment", {
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
          Add Equipment
        </Button>
      </DialogTrigger>
      <DialogContent>
        <form onSubmit={handleSubmit}>
          <DialogHeader>
            <DialogTitle>Register New Equipment</DialogTitle>
            <DialogDescription>
              Add a new equipment controller to your greenhouse system.
            </DialogDescription>
          </DialogHeader>

          <div className="py-4">
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="serial">Equipment Serial</FieldLabel>
                <Input
                  id="serial"
                  placeholder="pump_main_01"
                  value={serial}
                  onChange={(e) => setSerial(e.target.value)}
                  required
                  disabled={isLoading}
                />
              </Field>

              <Field>
                <FieldLabel htmlFor="name">Equipment Name</FieldLabel>
                <Input
                  id="name"
                  placeholder="Main Water Pump"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  required
                  disabled={isLoading}
                />
              </Field>

              <Field>
                <FieldLabel htmlFor="operations">
                  Supported Operations
                </FieldLabel>
                <Input
                  id="operations"
                  placeholder="ON, OFF, REVERSE"
                  value={operations}
                  onChange={(e) => setOperations(e.target.value)}
                  required
                  disabled={isLoading}
                />
                <p className="text-xs text-muted-foreground">
                  Comma-separated list of operations
                </p>
              </Field>

              <Field>
                <FieldLabel htmlFor="apiUrl">
                  API URL <span className="text-muted-foreground font-normal">(optional)</span>
                </FieldLabel>
                <Input
                  id="apiUrl"
                  placeholder="http://192.168.1.10/control"
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
                "Create Equipment"
              )}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

function ControlEquipmentDialog({ equipment }: { equipment: Equipment }) {
  const [open, setOpen] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [operation, setOperation] = useState(
    equipment.supported_operations[0] || ""
  );

  const handleControl = async () => {
    setIsLoading(true);

    try {
      await hardwareApi.controlEquipment(equipment.id, {
        operation,
      });

      toast.success("Command sent", {
        description: `${operation} command sent to ${equipment.name}.`,
      });

      mutate("equipment");
      setOpen(false);
    } catch (err) {
      if (err instanceof ApiError) {
        toast.error("Command failed", {
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
        <DropdownMenuItem onSelect={(e) => e.preventDefault()}>
          <Zap className="h-4 w-4 mr-2" />
          Send Command
        </DropdownMenuItem>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Control {equipment.name}</DialogTitle>
          <DialogDescription>
            Send a command to this equipment via MQTT.
          </DialogDescription>
        </DialogHeader>

        <div className="py-4">
          <Field>
            <FieldLabel htmlFor="operation">Operation</FieldLabel>
            <Select value={operation} onValueChange={setOperation}>
              <SelectTrigger id="operation">
                <SelectValue placeholder="Select operation" />
              </SelectTrigger>
              <SelectContent>
                {equipment.supported_operations.map((op) => (
                  <SelectItem key={op} value={op}>
                    {op}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </Field>

          <div className="mt-4 p-3 rounded-lg bg-muted text-sm">
            <p className="font-medium">MQTT Topic</p>
            <p className="text-muted-foreground font-mono text-xs mt-1">
              {equipment.mqtt_topic}
            </p>
          </div>
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
          <Button onClick={handleControl} disabled={isLoading}>
            {isLoading ? (
              <>
                <Spinner className="mr-2" />
                Sending...
              </>
            ) : (
              <>
                <Zap className="h-4 w-4 mr-2" />
                Send Command
              </>
            )}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function EditEquipmentDialog({ equipment }: { equipment: Equipment }) {
  const [open, setOpen] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [serial, setSerial] = useState(equipment.serial);
  const [name, setName] = useState(equipment.name);
  const [operations, setOperations] = useState(
    equipment.supported_operations.join(", ")
  );
  const [apiUrl, setApiUrl] = useState(equipment.api_url || "");

  const resetForm = () => {
    setSerial(equipment.serial);
    setName(equipment.name);
    setOperations(equipment.supported_operations.join(", "));
    setApiUrl(equipment.api_url || "");
  };

  const handleOpenChange = (nextOpen: boolean) => {
    setOpen(nextOpen);
    if (nextOpen) {
      resetForm();
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);

    try {
      await hardwareApi.updateEquipment(equipment.id, {
        serial,
        name,
        supported_operations: operations
          .split(",")
          .map((item) => item.trim())
          .filter(Boolean),
        api_url: apiUrl || undefined,
      });

      toast.success("Equipment updated", {
        description: `${name} has been updated successfully.`,
      });

      mutate("equipment");
      setOpen(false);
    } catch (err) {
      if (err instanceof ApiError) {
        toast.error("Failed to update equipment", {
          description: err.message,
        });
      }
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogTrigger asChild>
        <DropdownMenuItem onSelect={(e) => e.preventDefault()}>
          <Pencil className="h-4 w-4 mr-2" />
          Edit
        </DropdownMenuItem>
      </DialogTrigger>
      <DialogContent>
        <form onSubmit={handleSubmit}>
          <DialogHeader>
            <DialogTitle>Edit Equipment</DialogTitle>
            <DialogDescription>
              Update equipment details and supported operations.
            </DialogDescription>
          </DialogHeader>

          <div className="py-4">
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="edit-serial">Equipment Serial</FieldLabel>
                <Input
                  id="edit-serial"
                  value={serial}
                  onChange={(e) => setSerial(e.target.value)}
                  required
                  disabled={isLoading}
                />
              </Field>

              <Field>
                <FieldLabel htmlFor="edit-name">Equipment Name</FieldLabel>
                <Input
                  id="edit-name"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  required
                  disabled={isLoading}
                />
              </Field>

              <Field>
                <FieldLabel htmlFor="edit-operations">
                  Supported Operations
                </FieldLabel>
                <Input
                  id="edit-operations"
                  value={operations}
                  onChange={(e) => setOperations(e.target.value)}
                  required
                  disabled={isLoading}
                />
              </Field>

              <Field>
                <FieldLabel htmlFor="edit-api-url">
                  API URL <span className="text-muted-foreground font-normal">(optional)</span>
                </FieldLabel>
                <Input
                  id="edit-api-url"
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
                  Saving...
                </>
              ) : (
                "Save Changes"
              )}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

function DeleteEquipmentDialog({ equipment }: { equipment: Equipment }) {
  const [open, setOpen] = useState(false);
  const [isLoading, setIsLoading] = useState(false);

  const handleDelete = async () => {
    setIsLoading(true);
    try {
      await hardwareApi.deleteEquipment(equipment.id);
      toast.success("Equipment deleted", {
        description: `${equipment.name} has been removed.`,
      });
      mutate("equipment");
      setOpen(false);
    } catch (err) {
      if (err instanceof ApiError) {
        toast.error("Failed to delete equipment", {
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
        <DropdownMenuItem
          onSelect={(e) => {
            e.preventDefault();
            setOpen(true);
          }}
          className="text-destructive"
        >
          <Trash2 className="h-4 w-4 mr-2" />
          Delete
        </DropdownMenuItem>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Delete Equipment</DialogTitle>
          <DialogDescription>
            This will permanently delete {equipment.name}. This action cannot be undone.
          </DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <Button
            type="button"
            variant="outline"
            onClick={() => setOpen(false)}
            disabled={isLoading}
          >
            Cancel
          </Button>
          <Button variant="destructive" onClick={handleDelete} disabled={isLoading}>
            {isLoading ? (
              <>
                <Spinner className="mr-2" />
                Deleting...
              </>
            ) : (
              "Delete"
            )}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function EquipmentRow({ equipment }: { equipment: Equipment }) {
  return (
    <TableRow>
      <TableCell>
        <div className="flex items-center gap-3">
          <div
            className={`p-2 rounded-lg ${
              equipment.current_status === "ON"
                ? "bg-emerald-500/10"
                : "bg-muted"
            }`}
          >
            <Server
              className={`h-4 w-4 ${
                equipment.current_status === "ON"
                  ? "text-emerald-600"
                  : "text-muted-foreground"
              }`}
            />
          </div>
          <div>
            <p className="font-medium">{equipment.name}</p>
            <p className="text-xs text-muted-foreground font-mono">
              {equipment.serial}
            </p>
          </div>
        </div>
      </TableCell>
      <TableCell>
        <div className="flex flex-wrap gap-1">
          {equipment.supported_operations.map((op) => (
            <Badge key={op} variant="secondary" className="text-xs">
              {op}
            </Badge>
          ))}
        </div>
      </TableCell>
      <TableCell>{getStatusBadge(equipment.current_status)}</TableCell>
      <TableCell>
        <code className="text-xs bg-muted px-2 py-1 rounded">
          {equipment.mqtt_topic}
        </code>
      </TableCell>
      <TableCell>
        {new Date(equipment.created_at).toLocaleDateString()}
      </TableCell>
      <TableCell>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon-sm">
              <MoreHorizontal className="h-4 w-4" />
              <span className="sr-only">Actions</span>
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <ControlEquipmentDialog equipment={equipment} />
            <EditEquipmentDialog equipment={equipment} />
            <DropdownMenuSeparator />
            <DeleteEquipmentDialog equipment={equipment} />
          </DropdownMenuContent>
        </DropdownMenu>
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

export default function EquipmentPage() {
  const { isLoading: authLoading } = useRequireAuth("Admin");
  const { data: equipment, isLoading: equipmentLoading } = useEquipment();

  const isLoading = authLoading || equipmentLoading;

  return (
    <div className="p-6">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-balance">Equipment Management</h1>
          <p className="text-muted-foreground">
            Register and control your greenhouse equipment
          </p>
        </div>
        <AddEquipmentDialog />
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Registered Equipment</CardTitle>
          <CardDescription>
            All equipment controllers connected to your system
          </CardDescription>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <TableSkeleton />
          ) : !equipment || equipment.length === 0 ? (
            <div className="text-center py-12">
              <Server className="h-12 w-12 mx-auto mb-4 text-muted-foreground/50" />
              <h3 className="font-medium mb-1">No equipment registered</h3>
              <p className="text-sm text-muted-foreground mb-4">
                Add your first equipment to start controlling your greenhouse
              </p>
              <AddEquipmentDialog />
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Equipment</TableHead>
                  <TableHead>Operations</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>MQTT Topic</TableHead>
                  <TableHead>Created</TableHead>
                  <TableHead className="w-12"></TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {equipment.map((item) => (
                  <EquipmentRow key={item.id} equipment={item} />
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
