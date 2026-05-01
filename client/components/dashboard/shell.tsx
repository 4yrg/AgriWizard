"use client";

import { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useAuth } from "@/lib/auth/context";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Sheet, SheetContent, SheetTrigger } from "@/components/ui/sheet";
import {
  Leaf,
  LayoutDashboard,
  Server,
  Activity,
  Thermometer,
  Cloud,
  Menu,
  LogOut,
  User,
  ChevronRight,
} from "lucide-react";
import { NotificationsPopover } from "@/components/dashboard/notifications-popover";

interface NavItem {
  title: string;
  href: string;
  icon: React.ComponentType<{ className?: string }>;
}

const adminNavItems: NavItem[] = [
  { title: "Dashboard", href: "/admin", icon: LayoutDashboard },
  { title: "Equipment", href: "/admin/equipment", icon: Server },
  { title: "Sensors", href: "/admin/sensors", icon: Activity },
];

const agronomistNavItems: NavItem[] = [
  { title: "Dashboard", href: "/agronomist", icon: LayoutDashboard },
  { title: "Thresholds", href: "/agronomist/thresholds", icon: Thermometer },
  { title: "Weather", href: "/agronomist/weather", icon: Cloud },
];

function NavLink({ item, onClick }: { item: NavItem; onClick?: () => void }) {
  const pathname = usePathname();
  const isActive = pathname === item.href;

  return (
    <Link
      href={item.href}
      onClick={onClick}
      className={cn(
        "flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors",
        isActive
          ? "bg-primary text-primary-foreground"
          : "text-muted-foreground hover:bg-muted hover:text-foreground"
      )}
    >
      <item.icon className="h-4 w-4" />
      {item.title}
    </Link>
  );
}

function Sidebar({ items }: { items: NavItem[] }) {
  return (
    <aside className="hidden lg:flex lg:flex-col lg:w-64 lg:fixed lg:inset-y-0 border-r bg-card">
      {/* Logo */}
      <div className="flex items-center gap-2 h-16 px-6 border-b">
        <div className="flex items-center justify-center w-8 h-8 rounded-lg bg-primary">
          <Leaf className="w-4 h-4 text-primary-foreground" />
        </div>
        <span className="font-semibold">AgriWizard</span>
      </div>

      {/* Navigation */}
      <nav className="flex-1 px-4 py-6 space-y-1">
        {items.map((item) => (
          <NavLink key={item.href} item={item} />
        ))}
      </nav>
    </aside>
  );
}

function MobileNav({ items }: { items: NavItem[] }) {
  const [open, setOpen] = useState(false);

  return (
    <Sheet open={open} onOpenChange={setOpen}>
      <SheetTrigger asChild>
        <Button variant="ghost" size="icon" className="lg:hidden">
          <Menu className="h-5 w-5" />
          <span className="sr-only">Toggle menu</span>
        </Button>
      </SheetTrigger>
      <SheetContent side="left" className="w-64 p-0">
        {/* Logo */}
        <div className="flex items-center gap-2 h-16 px-6 border-b">
          <div className="flex items-center justify-center w-8 h-8 rounded-lg bg-primary">
            <Leaf className="w-4 h-4 text-primary-foreground" />
          </div>
          <span className="font-semibold">AgriWizard</span>
        </div>

        {/* Navigation */}
        <nav className="flex-1 px-4 py-6 space-y-1">
          {items.map((item) => (
            <NavLink
              key={item.href}
              item={item}
              onClick={() => setOpen(false)}
            />
          ))}
        </nav>
      </SheetContent>
    </Sheet>
  );
}

function Header({ items }: { items: NavItem[] }) {
  const { user, logout } = useAuth();
  const pathname = usePathname();

  // Find current page title
  const currentItem = items.find((item) => pathname === item.href);
  const parentItem = items.find(
    (item) => pathname.startsWith(item.href) && item.href !== pathname
  );

  const initials = user?.full_name
    ? user.full_name
        .split(" ")
        .map((n) => n[0])
        .join("")
        .toUpperCase()
        .slice(0, 2)
    : "U";

  return (
    <header className="sticky top-0 z-40 flex items-center justify-between h-16 px-4 lg:px-6 border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
      <div className="flex items-center gap-4">
        <MobileNav items={items} />

        {/* Breadcrumb */}
        <div className="hidden sm:flex items-center gap-2 text-sm">
          <span className="text-muted-foreground">
            {user?.role === "Admin" ? "Admin" : "Agronomist"}
          </span>
          {(currentItem || parentItem) && (
            <>
              <ChevronRight className="h-4 w-4 text-muted-foreground" />
              <span className="font-medium">
                {currentItem?.title || parentItem?.title}
              </span>
            </>
          )}
        </div>
      </div>

      <div className="flex items-center gap-2">
        <NotificationsPopover />

        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" className="flex items-center gap-2">
              <Avatar className="h-8 w-8">
                <AvatarFallback className="text-xs">{initials}</AvatarFallback>
              </Avatar>
              <span className="hidden sm:inline text-sm font-medium">
                {user?.full_name}
              </span>
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="w-56">
            <DropdownMenuLabel>
              <div className="flex flex-col">
                <span>{user?.full_name}</span>
                <span className="text-xs font-normal text-muted-foreground">
                  {user?.email}
                </span>
              </div>
            </DropdownMenuLabel>
            <DropdownMenuSeparator />
            <DropdownMenuItem asChild>
              <Link href="/profile" className="flex items-center">
                <User className="h-4 w-4 mr-2" />
                Profile
              </Link>
            </DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem
              onClick={logout}
              className="text-destructive focus:text-destructive"
            >
              <LogOut className="h-4 w-4 mr-2" />
              Sign out
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
    </header>
  );
}

export function DashboardShell({ children }: { children: React.ReactNode }) {
  const { user, isLoading } = useAuth();

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-primary animate-pulse" />
          <span className="font-semibold">Loading...</span>
        </div>
      </div>
    );
  }

  if (!user) {
    return null;
  }

  const navItems = user.role === "Admin" ? adminNavItems : agronomistNavItems;

  return (
    <div className="min-h-screen bg-background">
      <Sidebar items={navItems} />
      <div className="lg:pl-64">
        <Header items={navItems} />
        <main className="min-h-[calc(100vh-4rem)]">{children}</main>
      </div>
    </div>
  );
}
