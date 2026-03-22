import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "AgriWizard - Authentication",
  description: "Sign in or create an account to manage your smart greenhouse",
};

export default function AuthLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return <>{children}</>;
}
