"use client";

import {
  createContext,
  useContext,
  useEffect,
  useState,
  useCallback,
  type ReactNode,
} from "react";
import { useRouter, usePathname } from "next/navigation";
import type { UserDTO, LoginRequest, RegisterRequest, UserRole } from "@/types/api";
import { iamApi, ApiError } from "@/lib/api/client";

// ════════════════════════════════════════════════════════════════════════════
// Auth Context Types
// ════════════════════════════════════════════════════════════════════════════

interface AuthState {
  user: UserDTO | null;
  isLoading: boolean;
  isAuthenticated: boolean;
}

interface AuthContextValue extends AuthState {
  login: (data: LoginRequest) => Promise<void>;
  register: (data: RegisterRequest) => Promise<void>;
  logout: () => void;
  hasRole: (role: UserRole) => boolean;
}

const AuthContext = createContext<AuthContextValue | null>(null);

// ════════════════════════════════════════════════════════════════════════════
// Auth Provider
// ════════════════════════════════════════════════════════════════════════════

const PUBLIC_PATHS = ["/login", "/register", "/"];

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>({
    user: null,
    isLoading: true,
    isAuthenticated: false,
  });
  const router = useRouter();
  const pathname = usePathname();

  // Check authentication on mount
  useEffect(() => {
    const checkAuth = async () => {
      const token = localStorage.getItem("auth_token");
      
      if (!token) {
        setState({ user: null, isLoading: false, isAuthenticated: false });
        return;
      }

      try {
        const response = await iamApi.getProfile();
        setState({
          user: response.data,
          isLoading: false,
          isAuthenticated: true,
        });
      } catch (error) {
        // Token invalid or expired
        localStorage.removeItem("auth_token");
        setState({ user: null, isLoading: false, isAuthenticated: false });
      }
    };

    checkAuth();
  }, []);

  // Redirect based on auth state
  useEffect(() => {
    if (state.isLoading) return;

    const isPublicPath = PUBLIC_PATHS.includes(pathname);

    if (!state.isAuthenticated && !isPublicPath) {
      router.push("/login");
    } else if (state.isAuthenticated && (pathname === "/login" || pathname === "/register")) {
      // Redirect to appropriate dashboard based on role
      const redirectPath = state.user?.role === "Admin" ? "/admin" : "/agronomist";
      router.push(redirectPath);
    }
  }, [state.isAuthenticated, state.isLoading, pathname, router, state.user?.role]);

  const login = useCallback(async (data: LoginRequest) => {
    const response = await iamApi.login(data);
    localStorage.setItem("auth_token", response.token);
    setState({
      user: response.user,
      isLoading: false,
      isAuthenticated: true,
    });

    // Redirect to appropriate dashboard
    const redirectPath = response.user.role === "Admin" ? "/admin" : "/agronomist";
    router.push(redirectPath);
  }, [router]);

  const register = useCallback(async (data: RegisterRequest) => {
    await iamApi.register(data);
    // After registration, log the user in
    await login({ email: data.email, password: data.password });
  }, [login]);

  const logout = useCallback(() => {
    localStorage.removeItem("auth_token");
    setState({ user: null, isLoading: false, isAuthenticated: false });
    router.push("/login");
  }, [router]);

  const hasRole = useCallback(
    (role: UserRole) => state.user?.role === role,
    [state.user?.role]
  );

  return (
    <AuthContext.Provider
      value={{
        ...state,
        login,
        register,
        logout,
        hasRole,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

// ════════════════════════════════════════════════════════════════════════════
// Auth Hooks
// ════════════════════════════════════════════════════════════════════════════

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
}

export function useRequireAuth(requiredRole?: UserRole) {
  const auth = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (auth.isLoading) return;

    if (!auth.isAuthenticated) {
      router.push("/login");
      return;
    }

    if (requiredRole && auth.user?.role !== requiredRole) {
      // Redirect to their appropriate dashboard if they don't have access
      const redirectPath = auth.user?.role === "Admin" ? "/admin" : "/agronomist";
      router.push(redirectPath);
    }
  }, [auth.isAuthenticated, auth.isLoading, auth.user?.role, requiredRole, router]);

  return auth;
}
