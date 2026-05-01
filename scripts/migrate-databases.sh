#!/bin/bash
#
# Database Migration Script for Per-Service Databases
# Migrates schema from single 'agriwizard' database to per-service databases
#
# Usage:
#   From Azure Cloud Shell:
#     bash migrate-databases.sh
#
#   From GitHub Actions:
#     - Add to CI pipeline with Azure login context
#

set -euo pipefail

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║   AgriWizard Database Migration: Single DB → Per-Service DBs   ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Configuration
DB_HOST="agriwizard-prod-db-7i7k3p7kcgay2.postgres.database.azure.com"
DB_USER="agriwizard_admin"
RESOURCE_GROUP="agriwizard-prod-rg"
KEY_VAULT="agriwizard-prod-kv"

# Fetch credentials from Key Vault
echo "🔐 Retrieving database password from Key Vault..."
DB_PASSWORD=$(az keyvault secret show --vault-name "$KEY_VAULT" --name db-password --query 'value' -o tsv)

if [ -z "$DB_PASSWORD" ]; then
  echo "❌ ERROR: Could not retrieve DB password from Key Vault"
  exit 1
fi

export PGPASSWORD="$DB_PASSWORD"

echo "✅ Database credentials retrieved"
echo ""

# Verify connectivity
echo "🔗 Testing connection to PostgreSQL server..."
if psql -h "$DB_HOST" -U "$DB_USER" -d postgres -c "SELECT NOW();" &>/dev/null; then
  echo "✅ Connected successfully"
else
  echo "❌ ERROR: Could not connect to PostgreSQL server"
  exit 1
fi

echo ""
echo "📋 Starting schema migration for all services..."
echo ""

# Migration SQL for each service
declare -A SCHEMAS

# IAM Service Schema
SCHEMAS[iam]='
  CREATE SCHEMA IF NOT EXISTS iam;
  
  CREATE TABLE IF NOT EXISTS iam.users (
    id            TEXT PRIMARY KEY,
    email         TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role          TEXT NOT NULL DEFAULT '"'"'Agromist'"'"',
    full_name     TEXT NOT NULL,
    phone         TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
  );
  
  CREATE INDEX IF NOT EXISTS idx_iam_users_email ON iam.users(email);
  
  CREATE TABLE IF NOT EXISTS iam.tokens (
    token_id      TEXT PRIMARY KEY,
    user_id       TEXT NOT NULL REFERENCES iam.users(id),
    issued_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at    TIMESTAMPTZ NOT NULL,
    revoked_at    TIMESTAMPTZ
  );
  
  CREATE INDEX IF NOT EXISTS idx_iam_tokens_user ON iam.tokens(user_id);
'

# Hardware Service Schema
SCHEMAS[hardware]='
  CREATE SCHEMA IF NOT EXISTS hardware;
  
  CREATE TABLE IF NOT EXISTS hardware.equipment (
    id           TEXT PRIMARY KEY,
    name         TEXT NOT NULL,
    type         TEXT NOT NULL,
    location     TEXT,
    status       TEXT NOT NULL DEFAULT '"'"'active'"'"',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
  );
  
  CREATE TABLE IF NOT EXISTS hardware.sensors (
    id           TEXT PRIMARY KEY,
    equipment_id TEXT NOT NULL REFERENCES hardware.equipment(id),
    sensor_type  TEXT NOT NULL,
    unit         TEXT NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
  );
  
  CREATE TABLE IF NOT EXISTS hardware.sensor_readings (
    id          TEXT PRIMARY KEY,
    sensor_id   TEXT NOT NULL REFERENCES hardware.sensors(id),
    value       FLOAT NOT NULL,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  );
  
  CREATE INDEX IF NOT EXISTS idx_hardware_sensors_equipment ON hardware.sensors(equipment_id);
  CREATE INDEX IF NOT EXISTS idx_hardware_readings_sensor ON hardware.sensor_readings(sensor_id);
  CREATE INDEX IF NOT EXISTS idx_hardware_readings_time ON hardware.sensor_readings(recorded_at DESC);
'

# Analytics Service Schema
SCHEMAS[analytics]='
  CREATE SCHEMA IF NOT EXISTS analytics;
  
  CREATE TABLE IF NOT EXISTS analytics.thresholds (
    id              TEXT PRIMARY KEY,
    parameter_type  TEXT NOT NULL,
    min_value       FLOAT,
    max_value       FLOAT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
  );
  
  CREATE TABLE IF NOT EXISTS analytics.rules (
    id              TEXT PRIMARY KEY,
    parameter_type  TEXT NOT NULL,
    condition       TEXT NOT NULL,
    action          TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
  );
  
  CREATE TABLE IF NOT EXISTS analytics.decisions (
    id              TEXT PRIMARY KEY,
    rule_id         TEXT NOT NULL REFERENCES analytics.rules(id),
    parameter_type  TEXT NOT NULL,
    decision        TEXT NOT NULL,
    recorded_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
  );
  
  CREATE INDEX IF NOT EXISTS idx_analytics_decisions_rule ON analytics.decisions(rule_id);
  CREATE INDEX IF NOT EXISTS idx_analytics_decisions_time ON analytics.decisions(recorded_at DESC);
'

# Weather Service Schema  
SCHEMAS[weather]='
  CREATE SCHEMA IF NOT EXISTS weather;
  
  CREATE TABLE IF NOT EXISTS weather.cache (
    location      TEXT PRIMARY KEY,
    data          JSONB NOT NULL,
    cached_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at    TIMESTAMPTZ NOT NULL
  );
  
  CREATE TABLE IF NOT EXISTS weather.alerts (
    id            TEXT PRIMARY KEY,
    location      TEXT NOT NULL,
    alert_type    TEXT NOT NULL,
    severity      TEXT NOT NULL,
    message       TEXT NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at    TIMESTAMPTZ
  );
  
  CREATE INDEX IF NOT EXISTS idx_weather_alerts_location ON weather.alerts(location);
  CREATE INDEX IF NOT EXISTS idx_weather_alerts_time ON weather.alerts(created_at DESC);
'

# Notification Service Schema
SCHEMAS[notification]='
  CREATE SCHEMA IF NOT EXISTS notification;
  
  CREATE TABLE IF NOT EXISTS notification.messages (
    id         TEXT PRIMARY KEY,
    recipient  TEXT NOT NULL,
    subject    TEXT NOT NULL,
    body       TEXT NOT NULL,
    status     TEXT NOT NULL DEFAULT '"'"'pending'"'"',
    sent_at    TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  );
  
  CREATE TABLE IF NOT EXISTS notification.templates (
    id          TEXT PRIMARY KEY,
    name        TEXT UNIQUE NOT NULL,
    subject     TEXT NOT NULL,
    body_template TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
  );
  
  CREATE INDEX IF NOT EXISTS idx_notification_messages_recipient ON notification.messages(recipient);
  CREATE INDEX IF NOT EXISTS idx_notification_messages_status ON notification.messages(status);
  CREATE INDEX IF NOT EXISTS idx_notification_messages_time ON notification.messages(created_at DESC);
'

# Databases to migrate to
declare -A DATABASES
DATABASES[iam]="agriwizard-iam-prod"
DATABASES[hardware]="agriwizard-hardware-prod"
DATABASES[analytics]="agriwizard-analytics-prod"
DATABASES[weather]="agriwizard-weather-prod"
DATABASES[notification]="agriwizard-notification-prod"

# Execute migrations
failed=0
for service in iam hardware analytics weather notification; do
  db="${DATABASES[$service]}"
  schema="${SCHEMAS[$service]}"
  
  echo "📦 Migrating $service → $db"
  
  if psql -h "$DB_HOST" -U "$DB_USER" -d "$db" -c "$schema" &>/dev/null; then
    echo "   ✅ Schema created successfully"
  else
    echo "   ❌ ERROR: Schema creation failed"
    ((failed++))
  fi
done

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"

if [ $failed -eq 0 ]; then
  echo "║   ✅ All database migrations completed successfully!           ║"
  echo "╚════════════════════════════════════════════════════════════════╝"
  echo ""
  echo "Next steps:"
  echo "1. Restart services to pick up new schema:"
  echo ""
  echo "   for service in iam hardware analytics weather notification; do"
  echo "     az containerapp update -g $RESOURCE_GROUP -n \$service-prod \\"
  echo "       --set-env-vars RESTART_TIMESTAMP=\"\$(date +%s)\""
  echo "   done"
  echo ""
  echo "2. Check service logs for successful connection:"
  echo ""
  echo "   az containerapp logs show -g $RESOURCE_GROUP -n iam-prod --tail 50"
  echo ""
else
  echo "║   ❌ $failed migration(s) failed. See errors above.             ║"
  echo "╚════════════════════════════════════════════════════════════════╝"
  exit 1
fi
