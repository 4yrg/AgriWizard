#!/bin/bash
# AgriWizard Deployment Script
# Run this after GitHub Actions builds and pushes images

set -e

# Configuration
RESOURCE_GROUP="agriwizard-rg"
REGISTRY="agriwizard.azurecr.io"

# Get image tag from user or use latest
TAG=${1:-latest}
PREFIX=${2:-prod}

echo "========================================="
echo "AgriWizard Deployment Script"
echo "========================================="
echo "Resource Group: $RESOURCE_GROUP"
echo "Registry: $REGISTRY"
echo "Image Tag: $TAG"
echo "Service Prefix: $PREFIX"
echo "========================================="

# Login to Azure
echo "Logging into Azure..."
az login

# Set subscription
echo "Setting subscription..."
az account set --subscription 911cf5d3-ab4a-4897-9e23-244536f28127

# Deploy each service
echo ""
echo "Deploying services..."

# IAM Service
echo "→ Deploying IAM Service..."
az containerapp update \
  --name ${PREFIX}-iam-service \
  --resource-group ${RESOURCE_GROUP} \
  --image ${REGISTRY}/agriwizard-iam-service:${TAG} \
  --set-env-vars DB_SSLMODE=require \
  --format json > /dev/null 2>&1 && echo "  ✓ IAM Service deployed" || echo "  ✗ IAM Service failed"

# Hardware Service
echo "→ Deploying Hardware Service..."
az containerapp update \
  --name ${PREFIX}-hardware-service \
  --resource-group ${RESOURCE_GROUP} \
  --image ${REGISTRY}/agriwizard-hardware-service:${TAG} \
  --set-env-vars DB_SSLMODE=require \
  --format json > /dev/null 2>&1 && echo "  ✓ Hardware Service deployed" || echo "  ✗ Hardware Service failed"

# Analytics Service
echo "→ Deploying Analytics Service..."
az containerapp update \
  --name ${PREFIX}-analytics-service \
  --resource-group ${RESOURCE_GROUP} \
  --image ${REGISTRY}/agriwizard-analytics-service:${TAG} \
  --set-env-vars DB_SSLMODE=require \
  --format json > /dev/null 2>&1 && echo "  ✓ Analytics Service deployed" || echo "  ✗ Analytics Service failed"

# Weather Service
echo "→ Deploying Weather Service..."
az containerapp update \
  --name ${PREFIX}-weather-service \
  --resource-group ${RESOURCE_GROUP} \
  --image ${REGISTRY}/agriwizard-weather-service:${TAG} \
  --format json > /dev/null 2>&1 && echo "  ✓ Weather Service deployed" || echo "  ✗ Weather Service failed"

# Notification Service
echo "→ Deploying Notification Service..."
az containerapp update \
  --name ${PREFIX}-notification-service \
  --resource-group ${RESOURCE_GROUP} \
  --image ${REGISTRY}/agriwizard-notification-service:${TAG} \
  --set-env-vars DB_SSLMODE=require \
  --format json > /dev/null 2>&1 && echo "  ✓ Notification Service deployed" || echo "  ✗ Notification Service failed"

echo ""
echo "========================================="
echo "✅ Deployment completed!"
echo "========================================="

# Show service URLs
echo ""
echo "Service URLs:"
echo "IAM:        https://${PREFIX}-iam-service.$RESOURCE_GROUP.centralindia.azurecontainerapps.io"
echo "Hardware:   https://${PREFIX}-hardware-service.$RESOURCE_GROUP.centralindia.azurecontainerapps.io"
echo "Analytics:  https://${PREFIX}-analytics-service.$RESOURCE_GROUP.centralindia.azurecontainerapps.io"
echo "Weather:    https://${PREFIX}-weather-service.$RESOURCE_GROUP.centralindia.azurecontainerapps.io"
echo "Notification: https://${PREFIX}-notification-service.$RESOURCE_GROUP.centralindia.azurecontainerapps.io"
