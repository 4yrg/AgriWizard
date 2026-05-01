#!/bin/bash
#
# Database Migration Script for Per-Service Databases
#

set -euo pipefail

# Configuration
RESOURCE_GROUP="agriwizard-prod-rg"
DB_HOST="${DB_HOST:-}"
DB_USER="${DB_USER:-agriwizard_admin}"

if [ -z "$DB_HOST" ]; then
  DB_HOST=$(az postgres flexible-server list -g "$RESOURCE_GROUP" --query "[0].fullyQualifiedDomainName" -o tsv)
fi

KEY_VAULT=$(az keyvault list -g "$RESOURCE_GROUP" --query "[0].name" -o tsv)
DB_PASSWORD=$(az keyvault secret show --vault-name "$KEY_VAULT" --name db-password --query 'value' -o tsv)

export PGPASSWORD="$DB_PASSWORD"

# Migration SQL for each service
migrate_service() {
  local service=$1
  local db="agriwizard-$service-prod"
  local sql_file="/tmp/migrate-$service.sql"

  case "$service" in
    iam)
      cat <<EOF > "$sql_file"
CREATE SCHEMA IF NOT EXISTS iam;
CREATE TABLE IF NOT EXISTS iam.users (
  id TEXT PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'Agromist',
  full_name TEXT NOT NULL,
  phone TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
EOF
      ;;
    hardware)
      cat <<EOF > "$sql_file"
CREATE SCHEMA IF NOT EXISTS hardware;
CREATE TABLE IF NOT EXISTS hardware.equipment (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  location TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS hardware.sensors (
  id TEXT PRIMARY KEY,
  equipment_id TEXT NOT NULL REFERENCES hardware.equipment(id),
  sensor_type TEXT NOT NULL,
  unit TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS hardware.sensor_readings (
  id TEXT PRIMARY KEY,
  sensor_id TEXT NOT NULL REFERENCES hardware.sensors(id),
  value FLOAT NOT NULL,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
EOF
      ;;
    analytics)
      cat <<EOF > "$sql_file"
CREATE SCHEMA IF NOT EXISTS analytics;
CREATE TABLE IF NOT EXISTS analytics.thresholds (
  id TEXT PRIMARY KEY,
  parameter_type TEXT NOT NULL,
  min_value FLOAT,
  max_value FLOAT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
EOF
      ;;
    weather)
      cat <<EOF > "$sql_file"
CREATE SCHEMA IF NOT EXISTS weather;
CREATE TABLE IF NOT EXISTS weather.cache (
  location TEXT PRIMARY KEY,
  data JSONB NOT NULL,
  cached_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL
);
EOF
      ;;
    notification)
      cat <<EOF > "$sql_file"
CREATE SCHEMA IF NOT EXISTS notification;
CREATE TABLE IF NOT EXISTS notification.messages (
  id TEXT PRIMARY KEY,
  recipient TEXT NOT NULL,
  subject TEXT NOT NULL,
  body TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
EOF
      ;;
  esac

  echo "📦 Migrating $service → $db"
  psql -h "$DB_HOST" -U "$DB_USER" -d "$db" -f "$sql_file" > /dev/null
  echo "   ✅ Success"
}

for s in iam hardware analytics weather notification; do
  migrate_service "$s"
done

echo "✅ All migrations completed!"
