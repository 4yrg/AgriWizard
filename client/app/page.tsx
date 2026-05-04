"use client";

import Image from "next/image";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import {
  Leaf,
  Server,
  Activity,
  BarChart3,
  Cloud,
  Shield,
  ArrowRight,
} from "lucide-react";

const features = [
  {
    icon: Server,
    title: "Hardware Management",
    description:
      "Monitor and control equipment with real-time status updates and MQTT integration.",
  },
  {
    icon: Activity,
    title: "Sensor Network",
    description:
      "Provision sensors and collect telemetry data from across your greenhouse.",
  },
  {
    icon: BarChart3,
    title: "Analytics Dashboard",
    description:
      "View decision tables, daily summaries, and system status at a glance.",
  },
  {
    icon: Cloud,
    title: "Weather Intelligence",
    description:
      "Get forecasts, alerts, and irrigation recommendations based on conditions.",
  },
  {
    icon: Leaf,
    title: "Threshold Automation",
    description:
      "Set parameter thresholds and automate equipment control based on sensor data.",
  },
  {
    icon: Shield,
    title: "Role-Based Access",
    description:
      "Separate dashboards for Admins and Agronomists with tailored features.",
  },
];

export default function LandingPage() {
  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="fixed top-0 left-0 right-0 z-50 border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
        <div className="container mx-auto flex items-center justify-between h-16 px-4">
          <div className="flex items-center gap-2">
            <div className="flex items-center justify-center w-8 h-8 rounded-lg bg-primary">
              <Leaf className="w-4 h-4 text-primary-foreground" />
            </div>
            <span className="font-semibold">AgriWizard</span>
          </div>
          <div className="flex items-center gap-3">
            <Button variant="ghost" asChild>
              <Link href="/login">Sign in</Link>
            </Button>
            <Button asChild>
              <Link href="/register">Get Started</Link>
            </Button>
          </div>
        </div>
      </header>

      {/* Hero */}
      <section className="pt-32 pb-20 px-4">
        <div className="container mx-auto max-w-4xl text-center">
          <div className="inline-flex items-center gap-2 px-3 py-1 mb-6 rounded-full bg-primary/10 text-primary text-sm font-medium">
            <Leaf className="w-4 h-4" />
            Smart Greenhouse Management
          </div>
          <h1 className="text-4xl md:text-6xl font-bold tracking-tight text-balance mb-6">
            Intelligent control for your greenhouse
          </h1>
          <p className="text-lg md:text-xl text-muted-foreground max-w-2xl mx-auto mb-8 text-pretty">
            Monitor hardware, analyze sensor data, and automate operations with
            a powerful platform built for modern agriculture.
          </p>
          <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
            <Button size="lg" asChild>
              <Link href="/register">
                Start Free Trial
                <ArrowRight className="w-4 h-4 ml-2" />
              </Link>
            </Button>
            <Button size="lg" variant="outline" asChild>
              <Link href="/login">Sign in to Dashboard</Link>
            </Button>
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="py-20 px-4 bg-muted/30">
        <div className="container mx-auto max-w-6xl">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold mb-4 text-balance">
              Everything you need to manage your greenhouse
            </h2>
            <p className="text-muted-foreground max-w-2xl mx-auto text-pretty">
              A complete solution with role-based dashboards, real-time
              monitoring, and intelligent automation.
            </p>
          </div>
          <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
            {features.map((feature) => (
              <div
                key={feature.title}
                className="p-6 rounded-xl border bg-card hover:shadow-md transition-shadow"
              >
                <div className="flex items-center justify-center w-12 h-12 rounded-lg bg-primary/10 mb-4">
                  <feature.icon className="w-6 h-6 text-primary" />
                </div>
                <h3 className="font-semibold mb-2">{feature.title}</h3>
                <p className="text-sm text-muted-foreground">
                  {feature.description}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Roles Section */}
      <section className="py-20 px-4">
        <div className="container mx-auto max-w-6xl">
          <div className="grid gap-8 lg:grid-cols-2">
            <div className="p-8 rounded-xl border bg-card">
              <div className="flex items-center gap-3 mb-4">
                <div className="flex items-center justify-center w-10 h-10 rounded-lg bg-primary">
                  <Shield className="w-5 h-5 text-primary-foreground" />
                </div>
                <h3 className="text-xl font-semibold">Admin Dashboard</h3>
              </div>
              <p className="text-muted-foreground mb-4">
                Full control over hardware infrastructure. Manage equipment,
                provision sensors, define parameters, and monitor system health.
              </p>
              <ul className="space-y-2 text-sm">
                <li className="flex items-center gap-2">
                  <div className="w-1.5 h-1.5 rounded-full bg-primary" />
                  Equipment registration and control
                </li>
                <li className="flex items-center gap-2">
                  <div className="w-1.5 h-1.5 rounded-full bg-primary" />
                  Sensor provisioning with MQTT topics
                </li>
                <li className="flex items-center gap-2">
                  <div className="w-1.5 h-1.5 rounded-full bg-primary" />
                  Parameter definition and telemetry
                </li>
                <li className="flex items-center gap-2">
                  <div className="w-1.5 h-1.5 rounded-full bg-primary" />
                  Real-time status monitoring
                </li>
              </ul>
            </div>

            <div className="p-8 rounded-xl border bg-card">
              <div className="flex items-center gap-3 mb-4">
                <div className="flex items-center justify-center w-10 h-10 rounded-lg bg-emerald-500">
                  <BarChart3 className="w-5 h-5 text-white" />
                </div>
                <h3 className="text-xl font-semibold">Agronomist Dashboard</h3>
              </div>
              <p className="text-muted-foreground mb-4">
                Analytics and automation tools. Set thresholds, create
                automation rules, and leverage weather intelligence.
              </p>
              <ul className="space-y-2 text-sm">
                <li className="flex items-center gap-2">
                  <div className="w-1.5 h-1.5 rounded-full bg-emerald-500" />
                  Threshold configuration and alerts
                </li>
                <li className="flex items-center gap-2">
                  <div className="w-1.5 h-1.5 rounded-full bg-emerald-500" />
                  Automation rule creation
                </li>
                <li className="flex items-center gap-2">
                  <div className="w-1.5 h-1.5 rounded-full bg-emerald-500" />
                  Weather forecasts and alerts
                </li>
                <li className="flex items-center gap-2">
                  <div className="w-1.5 h-1.5 rounded-full bg-emerald-500" />
                  Irrigation recommendations
                </li>
              </ul>
            </div>
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="py-20 px-4 bg-primary text-primary-foreground">
        <div className="container mx-auto max-w-4xl text-center">
          <h2 className="text-3xl font-bold mb-4 text-balance">
            Ready to optimize your greenhouse?
          </h2>
          <p className="text-primary-foreground/80 max-w-xl mx-auto mb-8 text-pretty">
            Join AgriWizard today and take control of your smart greenhouse with
            intelligent monitoring and automation.
          </p>
          <Button size="lg" variant="secondary" asChild>
            <Link href="/register">
              Get Started for Free
              <ArrowRight className="w-4 h-4 ml-2" />
            </Link>
          </Button>
        </div>
      </section>

      {/* Footer */}
      <footer className="py-8 px-4 border-t">
        <div className="container mx-auto flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-2">
            <div className="flex items-center justify-center w-6 h-6 rounded bg-primary">
              <Leaf className="w-3 h-3 text-primary-foreground" />
            </div>
            <span className="text-sm font-medium">AgriWizard</span>
          </div>
          <p className="text-sm text-muted-foreground">
            Smart Greenhouse Management System
          </p>
        </div>
      </footer>
    </div>
  );
}
