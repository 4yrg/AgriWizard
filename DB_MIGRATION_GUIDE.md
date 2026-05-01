# Database Migration Guide: Single DB → Per-Service DBs

## Overview
This guide documents the migration from a single shared `agriwizard` database to isolated per-service databases on the PostgreSQL Flexible Server.

## Current State
- **PostgreSQL Server**: `agriwizard-prod-db-7i7k3p7kcgay2.postgres.database.azure.com`
- **Existing Database**: `agriwizard` (contains all schemas for all services)
- **New Databases Created**:
  - `agriwizard-iam-prod`
  - `agriwizard-hardware-prod`
  - `agriwizard-analytics-prod`
  - `agriwizard-weather-prod`
  - `agriwizard-notification-prod`

## Container Apps Configuration
Each service now uses its own database via environment variable:

```
IAM Service:          DB_NAME=agriwizard-iam-prod
Hardware Service:     DB_NAME=agriwizard-hardware-prod
Analytics Service:    DB_NAME=agriwizard-analytics-prod
Weather Service:      DB_NAME=agriwizard-weather-prod
Notification Service: DB_NAME=agriwizard-notification-prod
```

## Migration Strategies

### Option A: Service-Driven Migration (Recommended)
Each service has built-in database migration logic. When a service starts:
1. It connects to its assigned database
2. It runs internal migration logic (golang-migrate, Flyway, etc.)
3. It creates schema and tables if they don't exist
4. It starts the application

**Advantages**:
- No manual migration needed
- Each service handles its own schema
- Self-healing on restart

**Implementation**:
```bash
# Services will auto-migrate on startup
# Just restart the services
for service in iam hardware analytics weather notification; do
  az containerapp update -g agriwizard-prod-rg -n "$service-prod" \
    --set-env-vars RESTART_TIMESTAMP="$(date +%s)"
done
```

### Option B: Manual Schema Dump & Restore
If services don't have built-in migration:

```bash
#!/bin/bash
DB_PASSWORD=$(az keyvault secret show --vault-name agriwizard-prod-kv --name db-password --query 'value' -o tsv)
DB_HOST="agriwizard-prod-db-7i7k3p7kcgay2.postgres.database.azure.com"
DB_USER="agriwizard_admin"

export PGPASSWORD="$DB_PASSWORD"

# Dump schema from old database
pg_dump -h "$DB_HOST" -U "$DB_USER" -d agriwizard \
  --schema-only --no-owner --no-privileges > /tmp/schema.sql

# Restore to each per-service database
for db in agriwizard-iam-prod agriwizard-hardware-prod \
          agriwizard-analytics-prod agriwizard-weather-prod \
          agriwizard-notification-prod; do
  echo "Migrating schema to $db..."
  psql -h "$DB_HOST" -U "$DB_USER" -d "$db" < /tmp/schema.sql
done
```

### Option C: Copy Entire Database with Data
If services need existing data:

```bash
#!/bin/bash
DB_PASSWORD=$(az keyvault secret show --vault-name agriwizard-prod-kv --name db-password --query 'value' -o tsv)
DB_HOST="agriwizard-prod-db-7i7k3p7kcgay2.postgres.database.azure.com"
DB_USER="agriwizard_admin"

export PGPASSWORD="$DB_PASSWORD"

# For each service, copy full database
for svc in iam hardware analytics weather notification; do
  target_db="agriwizard-${svc}-prod"
  echo "Copying agriwizard → $target_db..."
  
  # Dump and restore with data
  pg_dump -h "$DB_HOST" -U "$DB_USER" -d agriwizard | \
    psql -h "$DB_HOST" -U "$DB_USER" -d "$target_db"
done
```

## Verification

### Check Schema Exists
```bash
for db in agriwizard-iam-prod agriwizard-hardware-prod \
          agriwizard-analytics-prod agriwizard-weather-prod \
          agriwizard-notification-prod; do
  echo "Tables in $db:"
  psql -h agriwizard-prod-db-7i7k3p7kcgay2.postgres.database.azure.com \
    -U agriwizard_admin -d "$db" -c \
    "SELECT count(*) as table_count FROM information_schema.tables WHERE table_schema='public';"
done
```

### Check Service Logs
```bash
# Check for successful database connections
az containerapp logs show -g agriwizard-prod-rg -n iam-prod --tail 50 | \
  grep -i "success\|migration\|connected\|ready"
```

### Test Connection from Pod
```bash
# Exec into service pod and test connection
az containerapp exec -g agriwizard-prod-rg -n iam-prod \
  --command /bin/sh -- -c \
  'psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT NOW();"'
```

## Rollback Plan

If issues occur, revert services to single database:

```bash
# Update container apps to use old database
for service in iam hardware analytics weather notification; do
  az containerapp update -g agriwizard-prod-rg -n "$service-prod" \
    --set-env-vars DB_NAME=agriwizard
done
```

## Timeline

1. **Immediate**: Services configured to use per-service DBs ✓ (Done)
2. **Next Step**: Migrate schema/data using Option A, B, or C above
3. **Verification**: Confirm all services can connect and health checks pass
4. **Monitoring**: Watch logs for 1-2 hours for any issues
5. **Cutover**: All traffic uses new per-service databases

## Notes

- Keep old `agriwizard` database as backup during transition
- Firewall rules allow all Azure services (no changes needed)
- SSL/TLS required for connections (`DB_SSLMODE=require`)
- Each service can now scale and manage data independently
