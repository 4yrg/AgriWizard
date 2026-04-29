using 'infra/main.bicep'
param postgresAdminPassword = readEnvironmentVariable('POSTGRES_ADMIN_PASSWORD', '')
param jwtSecret = readEnvironmentVariable('JWT_SECRET', '')
param mqttBroker = readEnvironmentVariable('MQTT_BROKER', '')
param mqttUsername = readEnvironmentVariable('MQTT_USERNAME', '')
param mqttPassword = readEnvironmentVariable('MQTT_PASSWORD', '')
param owmApiKey = readEnvironmentVariable('OWM_API_KEY', '')
