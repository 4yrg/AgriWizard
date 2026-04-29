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

// Weather service location defaults (Colombo, Sri Lanka)
param locationLat = '6.9271'
param locationLon = '79.8612'
param locationCity = 'Colombo'

// SMTP defaults (override in CI for production email provider)
param smtpPort = '587'
param smtpFrom = 'noreply@agriwizard.local'

// ─────────────────────────────────────────────────────────────────────────────
// The following parameters MUST be provided via CI/CD --parameters overrides:
//   postgresAdminPassword
//   jwtSecret
//   mqttBroker
//   mqttUsername
//   mqttPassword
//   owmApiKey
//   smtpHost        (if using production email)
//   smtpUsername     (if using production email)
//   smtpPassword     (if using production email)
// ─────────────────────────────────────────────────────────────────────────────
