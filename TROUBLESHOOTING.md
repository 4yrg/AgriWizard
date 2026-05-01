# Database Connection Troubleshooting & Next Steps

## Status

✅ **Infrastructure Ready**:
- PostgreSQL server: `agriwizard-prod-db-7i7k3p7kcgay2.postgres.database.azure.com`
- 5 per-service databases created successfully
- All services configured with correct DB_NAME environment variables
- Services have auto-migration logic ready

⏳ **Services Attempting Connection**:
- Container Apps are failing to connect to databases
- Logs show: "DB connection attempt X/10 failed, retrying in 3s..."

## Root Cause Analysis

### Possible Issues

1. **Database doesn't have schema yet** - Most likely
   - New databases are empty
   - Services can't connect because they can't find tables
   - Solution: Run migrations

2. **Network connectivity** - Less likely but check
   - Firewall rules already allow Azure services
   - Can test with: `az postgres flexible-server db show`

3. **Credentials issue** - Can verify
   - All services use same credentials: `agriwizard_admin`
   - Password from Key Vault: `db-password`

## Resolution Steps

### Step 1: Verify Connectivity (From Azure Shell)
```bash
# Option A: Use Azure Portal Cloud Shell (has proper creds)
# Option B: From deployment pipeline (has Azure CLI context)

# Test connection
az postgres flexible-server connect \
  -n agriwizard-prod-db-7i7k3p7kcgay2 \
  -a agriwizard_admin \
  --database agriwizard-iam-prod \
  --query "SELECT NOW() as current_time"
```

### Step 2: Verify Service Logs Show Migrations
```bash
# After next restart, look for migration success logs
az containerapp logs show -g agriwizard-prod-rg -n iam-prod --tail 100 | \
  grep -i "migration\|schema\|created"
```

### Step 3: Manual Migration (If Auto-Migration Fails)

Save this as `migrate-databases.sh` and run from **Azure CLI** or **GitHub Actions**:

```bash
#!/bin/bash
set -euo pipefail

DB_PASSWORD=$(az keyvault secret show --vault-name agriwizard-prod-kv --name db-password --query 'value' -o tsv)
DB_HOST="agriwizard-prod-db-7i7k3p7kcgay2.postgres.database.azure.com"
DB_USER="agriwizard_admin"
export PGPASSWORD="$DB_PASSWORD"

echo "🔄 Starting database migrations..."
echo ""

# Function to run migration for a service
migrate_service() {
  local service=$1
  local db_name=$2
  
  echo "📦 Migrating $service to $db_name..."
  
  psql -h "$DB_HOST" -U "$DB_USER" -d "$db_name" << EOF
    -- IAM Schema
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
    CREATE INDEX IF NOT EXISTS idx_iam_users_email ON iam.users(email);
    
    -- Hardware Schema
    CREATE SCHEMA IF NOT EXISTS hardware;
    CREATE TABLE IF NOT EXISTS hardware.equipment (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'active',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    
    -- Analytics Schema
    CREATE SCHEMA IF NOT EXISTS analytics;
    CREATE TABLE IF NOT EXISTS analytics.metrics (
      id TEXT PRIMARY KEY,
      equipment_id TEXT NOT NULL,
      metric_value FLOAT NOT NULL,
      recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    
    -- Weather Schema (read-only via API, minimal schema)
    CREATE SCHEMA IF NOT EXISTS weather;
    CREATE TABLE IF NOT EXISTS weather.cache (
      location TEXT PRIMARY KEY,
      data JSONB NOT NULL,
      cached_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      expires_at TIMESTAMPTZ NOT NULL
    );
    
    -- Notification Schema
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
  
  if [ $? -eq 0 ]; then
    echo "✅ $service migration completed"
  else
    echo "❌ $service migration failed"
    return 1
  fi
}

# Migrate each service
migrate_service "iam" "agriwizard-iam-prod"
migrate_service "hardware" "agriwizard-hardware-prod"
migrate_service "analytics" "agriwizard-analytics-prod"
migrate_service "weather" "agriwizard-weather-prod"
migrate_service "notification" "agriwizard-notification-prod"

echo ""
echo "✅ All migrations completed!"
echo ""
echo "Next: Restart services to pick up new schema"
```

### Step 4: Restart Services

```bash
echo "🔄 Restarting services to pick up schema..."
for service in iam hardware analytics weather notification; do
  echo "  → Restarting $service-prod..."
  az containerapp update -g agriwizard-prod-rg -n "$service-prod" \
    --set-env-vars RESTART_TIMESTAMP="$(date +%s)" \
    --only-show-errors 2>&1 | grep -E "Updated|Error" || true
done
echo "✅ Restart commands sent. Services will be running in 30-60 seconds."
```

### Step 5: Verify Successful Connection

```bash
echo "🔍 Checking service health..."
sleep 30

for service in iam hardware analytics weather notification; do
  echo "=== Checking $service-prod ==="
  az containerapp logs show -g agriwizard-prod-rg -n "$service-prod" --tail 20 | \
    grep -E "connection|Connection|ready|Ready|started|ERROR" | tail -2
  echo ""
done
```

## Preferred Execution Path

### Option 1: Run from GitHub Actions (Recommended)
1. Create `.github/workflows/db-migrate.yml` with the migration script
2. Trigger the workflow manually
3. Services auto-restart and connect successfully

### Option 2: Run from Azure Portal Cloud Shell
1. Open Azure Portal → Cloud Shell (Bash)
2. Paste the migration script
3. Execute and monitor

### Option 3: Run Inline via Azure CLI
```bash
# One-liner to migrate all databases
az postgres flexible-server db update \
  -n agriwizard-prod-db-7i7k3p7kcgay2 \
  -d agriwizard-iam-prod \
  -g agriwizard-prod-rg \
  --execute-script /path/to/schema.sql
```

## Expected Outcome After Migration

After successful migration and service restart:

```
✅ iam-prod:          "IAM init complete, ready to serve"
✅ hardware-prod:     "Hardware service initialized"
✅ analytics-prod:    "Analytics engine ready"
✅ weather-prod:      "Weather service initialized"
✅ notification-prod: "Notification service started"
```

Logs will show:
```
✅ "Migration completed successfully"
✅ "Database schema ready"
✅ "Serving on port XXXX"
✅ "Health check: /health → 200 OK"
```

## Verification Checklist

- [ ] Migration script executed without errors
- [ ] Services restarted successfully
- [ ] Health endpoints return HTTP 200
- [ ] Service logs show successful DB connection
- [ ] Each service has data in its own database
- [ ] Gateway can route requests to backend services

## Rollback if Needed

```bash
# Revert all services to old database
for service in iam hardware analytics weather notification; do
  az containerapp update -g agriwizard-prod-rg -n "$service-prod" \
    --set-env-vars DB_NAME=agriwizard
done
```

## Key Files Created

1. **DB_MIGRATION_GUIDE.md** - Comprehensive migration strategies
2. **TROUBLESHOOTING.md** - This file, for connection issues
3. **migrate-databases.sh** - Automated migration script (run from Cloud Shell or Actions)
