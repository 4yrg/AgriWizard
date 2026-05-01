"use client";

import { useState } from "react";
import { Bell } from "lucide-react";
import { useAuth } from "@/lib/auth/context";
import { useNotifications, useUnreadCount } from "@/hooks/use-api";
import { notificationApi } from "@/lib/api/client";
import { Button } from "@/components/ui/button";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Separator } from "@/components/ui/separator";
import { cn } from "@/lib/utils";

function formatTimeAgo(dateStr: string): string {
  const date = new Date(dateStr);
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffMins = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMins / 60);
  const diffDays = Math.floor(diffHours / 24);

  if (diffMins < 1) return "Just now";
  if (diffMins < 60) return `${diffMins}m ago`;
  if (diffHours < 24) return `${diffHours}h ago`;
  if (diffDays < 7) return `${diffDays}d ago`;
  return date.toLocaleDateString();
}

export function NotificationsPopover() {
  const { user } = useAuth();
  const [open, setOpen] = useState(false);
  const recipient = user?.email ?? null;

  const { data: notifications, mutate: mutateNotifications } = useNotifications(recipient);
  const { data: unreadData, mutate: mutateUnread } = useUnreadCount(recipient);

  const unreadCount = unreadData?.count ?? 0;
  const items = notifications ?? [];

  const handleMarkAsRead = async (id: string) => {
    await notificationApi.markAsRead(id);
    mutateNotifications();
    mutateUnread();
  };

  const handleMarkAllAsRead = async () => {
    if (!recipient) return;
    await notificationApi.markAllAsRead(recipient);
    mutateNotifications();
    mutateUnread();
  };

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button variant="ghost" size="icon" className="relative">
          <Bell className="h-5 w-5" />
          {unreadCount > 0 && (
            <span className="absolute -top-1 -right-1 flex h-4 w-4 items-center justify-center rounded-full bg-destructive text-[10px] font-bold text-white">
              {unreadCount > 9 ? "9+" : unreadCount}
            </span>
          )}
        </Button>
      </PopoverTrigger>
      <PopoverContent align="end" className="w-80 p-0">
        <div className="flex items-center justify-between px-4 py-3">
          <h4 className="text-sm font-semibold">Notifications</h4>
          {unreadCount > 0 && (
            <button
              onClick={handleMarkAllAsRead}
              className="text-xs text-muted-foreground hover:text-foreground transition-colors"
            >
              Mark all read
            </button>
          )}
        </div>
        <Separator />
        {items.length === 0 ? (
          <div className="flex items-center justify-center py-8 text-sm text-muted-foreground">
            No notifications
          </div>
        ) : (
          <ScrollArea className="h-[320px]">
            <div className="flex flex-col">
              {items.map((n) => (
                <div
                  key={n.id}
                  onClick={() => !n.read_at && handleMarkAsRead(n.id)}
                  className={cn(
                    "flex flex-col gap-1 px-4 py-3 cursor-pointer hover:bg-muted/50 transition-colors",
                    !n.read_at && "bg-muted/30"
                  )}
                >
                  <div className="flex items-start justify-between gap-2">
                    <span className="text-sm font-medium leading-tight line-clamp-1">
                      {n.subject}
                    </span>
                    {!n.read_at && (
                      <span className="mt-1 h-2 w-2 shrink-0 rounded-full bg-primary" />
                    )}
                  </div>
                  <p className="text-xs text-muted-foreground line-clamp-2">
                    {n.body}
                  </p>
                  <span className="text-[10px] text-muted-foreground">
                    {formatTimeAgo(n.created_at)}
                  </span>
                </div>
              ))}
            </div>
          </ScrollArea>
        )}
      </PopoverContent>
    </Popover>
  );
}