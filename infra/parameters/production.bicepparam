using '../main.bicep'

// ─────────────────────────────────────────────────────────────────────────────
// AgriWizard — Production Parameters
// ─────────────────────────────────────────────────────────────────────────────
// Non-sensitive defaults are set here. Sensitive values (passwords, secrets)
// are passed as --parameters overrides from the GitHub Actions workflow.
// ─────────────────────────────────────────────────────────────────────────────

param location = 'centralindia'
param environmentName = 'agriwizard'
param imageTag = 'latest'
param usePlaceholderImages = true

// Weather service location defaults (Colombo, Sri Lanka)
param locationLat = '6.9271'
param locationLon = '79.8612'
param locationCity = 'Colombo'

// SMTP defaults (override in CI for production email provider)
param smtpPort = '587'
param smtpFrom = 'noreply@agriwizard.local'

// ─────────────────────────────────────────────────────────────────────────────
// The following parameters are read from Environment Variables injected by
// GitHub Actions during the deployment workflow.
// ─────────────────────────────────────────────────────────────────────────────

param postgresAdminPassword = readEnvironmentVariable('POSTGRES_ADMIN_PASSWORD', '')
param jwtSecret = readEnvironmentVariable('JWT_SECRET', '')
param mqttBroker = readEnvironmentVariable('MQTT_BROKER', '')
param mqttUsername = readEnvironmentVariable('MQTT_USERNAME', '')
param mqttPassword = readEnvironmentVariable('MQTT_PASSWORD', '')
param owmApiKey = readEnvironmentVariable('OWM_API_KEY', '')
