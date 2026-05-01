# Gateway Nginx Deployment Guide

## Overview

The API gateway uses a templated nginx configuration that supports both **local Docker Compose** and **Azure Container Apps** deployments. The configuration is generated dynamically based on environment variables during container startup.

## Local Development (Docker Compose)

### Configuration
For local development, the gateway uses HTTP for all internal service routing:

```yaml
# These are already set in docker-compose.yml
IAM_SERVICE_HOST: iam-service:8086
IAM_SERVICE_PROTOCOL: http
IAM_SSL_CONFIG: ""

HARDWARE_SERVICE_HOST: hardware-service:8087
HARDWARE_SERVICE_PROTOCOL: http
HARDWARE_SSL_CONFIG: ""

# ... and so on for all services
```

### Running Locally
```bash
docker compose down && docker compose up -d gateway
```

### Testing
```bash
# Test IAM service
curl http://localhost:8080/api/v1/iam/health

# Test Hardware service
curl http://localhost:8080/api/v1/hardware/health
```

---

## Azure Container Apps Deployment

### Environment Variables

When deploying the gateway to Azure Container Apps, set these environment variables:

#### IAM Service
```
IAM_SERVICE_HOST=<iam-service-fqdn>
IAM_SERVICE_PROTOCOL=https
IAM_SSL_CONFIG=proxy_ssl_server_name on; proxy_ssl_verify on; proxy_ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt; proxy_ssl_verify_depth 2;
```

#### Hardware Service
```
HARDWARE_SERVICE_HOST=<hardware-service-fqdn>
HARDWARE_SERVICE_PROTOCOL=https
HARDWARE_SSL_CONFIG=proxy_ssl_server_name on; proxy_ssl_verify on; proxy_ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt; proxy_ssl_verify_depth 2;
```

#### Analytics Service
```
ANALYTICS_SERVICE_HOST=<analytics-service-fqdn>
ANALYTICS_SERVICE_PROTOCOL=https
ANALYTICS_SSL_CONFIG=proxy_ssl_server_name on; proxy_ssl_verify on; proxy_ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt; proxy_ssl_verify_depth 2;
```

#### Weather Service
```
WEATHER_SERVICE_HOST=<weather-service-fqdn>
WEATHER_SERVICE_PROTOCOL=https
WEATHER_SSL_CONFIG=proxy_ssl_server_name on; proxy_ssl_verify on; proxy_ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt; proxy_ssl_verify_depth 2;
```

#### Notification Service
```
NOTIFICATION_SERVICE_HOST=<notification-service-fqdn>
NOTIFICATION_SERVICE_PROTOCOL=https
NOTIFICATION_SSL_CONFIG=proxy_ssl_server_name on; proxy_ssl_verify on; proxy_ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt; proxy_ssl_verify_depth 2;
```

### Finding Service FQDNs

To get the FQDN of each Container App:

```bash
az containerapp show -g <resource-group> -n <app-name> --query "properties.configuration.ingress.fqdn" -o tsv
```

Example:
```bash
az containerapp show -g agriwizard-prod-rg -n iam-prod --query "properties.configuration.ingress.fqdn" -o tsv
# Output: iam-prod.region.azurecontainerapps.io
```

### Setting Variables via Azure CLI

```bash
RESOURCE_GROUP="agriwizard-prod-rg"
GATEWAY_NAME="gateway-prod"

# Get service FQDNs
IAM_FQDN=$(az containerapp show -g $RESOURCE_GROUP -n iam-prod --query "properties.configuration.ingress.fqdn" -o tsv)
HARDWARE_FQDN=$(az containerapp show -g $RESOURCE_GROUP -n hardware-prod --query "properties.configuration.ingress.fqdn" -o tsv)
ANALYTICS_FQDN=$(az containerapp show -g $RESOURCE_GROUP -n analytics-prod --query "properties.configuration.ingress.fqdn" -o tsv)
WEATHER_FQDN=$(az containerapp show -g $RESOURCE_GROUP -n weather-prod --query "properties.configuration.ingress.fqdn" -o tsv)
NOTIFICATION_FQDN=$(az containerapp show -g $RESOURCE_GROUP -n notification-prod --query "properties.configuration.ingress.fqdn" -o tsv)

SSL_CONFIG="proxy_ssl_server_name on; proxy_ssl_verify on; proxy_ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt; proxy_ssl_verify_depth 2;"

# Update gateway environment variables
az containerapp update \
  -g $RESOURCE_GROUP \
  -n $GATEWAY_NAME \
  --set-env-vars \
    IAM_SERVICE_HOST=$IAM_FQDN \
    IAM_SERVICE_PROTOCOL=https \
    IAM_SSL_CONFIG="$SSL_CONFIG" \
    HARDWARE_SERVICE_HOST=$HARDWARE_FQDN \
    HARDWARE_SERVICE_PROTOCOL=https \
    HARDWARE_SSL_CONFIG="$SSL_CONFIG" \
    ANALYTICS_SERVICE_HOST=$ANALYTICS_FQDN \
    ANALYTICS_SERVICE_PROTOCOL=https \
    ANALYTICS_SSL_CONFIG="$SSL_CONFIG" \
    WEATHER_SERVICE_HOST=$WEATHER_FQDN \
    WEATHER_SERVICE_PROTOCOL=https \
    WEATHER_SSL_CONFIG="$SSL_CONFIG" \
    NOTIFICATION_SERVICE_HOST=$NOTIFICATION_FQDN \
    NOTIFICATION_SERVICE_PROTOCOL=https \
    NOTIFICATION_SSL_CONFIG="$SSL_CONFIG"
```

### Verifying Deployment

After updating the gateway, verify it's working:

```bash
# Get the gateway FQDN
GATEWAY_FQDN=$(az containerapp show -g $RESOURCE_GROUP -n $GATEWAY_NAME --query "properties.configuration.ingress.fqdn" -o tsv)

# Test endpoints
curl https://$GATEWAY_FQDN/api/v1/iam/health
curl https://$GATEWAY_FQDN/api/v1/hardware/health
curl https://$GATEWAY_FQDN/api/v1/analytics/health
curl https://$GATEWAY_FQDN/api/v1/weather/health
curl https://$GATEWAY_FQDN/api/v1/notifications/health
```

---

## Configuration Template

The gateway uses `gateway/nginx.conf.template` which contains placeholders for:
- `${*_SERVICE_HOST}` - The service hostname/FQDN
- `${*_SERVICE_PROTOCOL}` - The protocol (http or https)
- `${*_SSL_CONFIG}` - SSL configuration directives (empty for HTTP, full config for HTTPS)

The `gateway/Dockerfile` substitutes these variables at container startup using `envsubst`.

---

## Troubleshooting

### Gateway returns 502 Bad Gateway
- **Cause**: Services are not reachable at the configured FQDNs
- **Solution**: 
  1. Verify service FQDNs are correct
  2. Check if services are running: `az containerapp list -g <resource-group>`
  3. Test connectivity: `curl https://<service-fqdn>/health`

### SSL Certificate Verification Fails
- **Cause**: Services don't have valid certificates or certificates aren't trusted
- **Solution**:
  - For production Azure services with managed certificates, this should work automatically
  - If you get SSL errors, temporarily set `IAM_SSL_CONFIG=""` to test without verification
  - Check certificate validity: `echo | openssl s_client -connect <fqdn>:443`

### Nginx Configuration Errors
- **Check nginx syntax**: `docker exec agriwizard-gateway nginx -t`
- **View generated config**: `docker exec agriwizard-gateway cat /etc/nginx/nginx.conf`
- **Check container logs**: `docker logs agriwizard-gateway`

---

## Best Practices

1. **Use HTTPS in production**: Always set `SERVICE_PROTOCOL=https` and include SSL verification for Azure deployments
2. **Keep SSL configs consistent**: Use the same SSL_CONFIG value for all services in production
3. **Test after deployment**: Run health check endpoints after updating gateway configuration
4. **Document FQDNs**: Store the service FQDNs in your deployment pipeline or CI/CD configuration
5. **Monitor gateway logs**: Regularly check gateway logs for routing or SSL errors
