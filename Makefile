.PHONY: help build up down logs clean test lint

help:
	@echo "AgriWizard - Local Development Commands"
	@echo "================================"
	@echo "make up           - Start all services (detached)"
	@echo "make down        - Stop all services"
	@echo "make logs        - View logs (all services)"
	@echo "make logs-<svc>  - View logs for specific service"
	@echo "make build      - Build all service images"
	@echo "make rebuild   - Rebuild and start"
	@echo "make clean     - Remove containers and volumes"
	@echo "make test     - Run tests"
	@echo "make lint     - Run linters"
	@echo ""
	@echo "Services:"
	@echo "  iam hardware analytics weather notification kong"

build:
	docker compose build

up:
	docker compose up -d
	@echo ""
	@echo "Services running:"
	@echo "  Kong Gateway:    http://localhost:8000"
	@echo "  IAM:         http://localhost:8081"
	@echo "  Hardware:    http://localhost:8082"
	@echo "  Analytics:   http://localhost:8083"
	@echo "  Weather:     http://localhost:8085"
	@echo "  Notification: http://localhost:8096"
	@echo "  RabbitMQ:    http://localhost:8093 (management)"
	@echo "  Mailhog:     http://localhost:8098 (UI)"
	@echo "  Swagger:    http://localhost:8090"
	@echo "  Frontend:   http://localhost:3000"

down:
	docker compose down

logs:
	docker compose logs -f

logs-iam:
	docker compose logs -f iam-service

logs-hardware:
	docker compose logs -f hardware-service

logs-analytics:
	docker compose logs -f analytics-service

logs-weather:
	docker compose logs -f weather-service

logs-notification:
	docker compose logs -f notification-service

logs-kong:
	docker compose logs -f kong

clean:
	docker compose down -v
	rm -rf client/.next

restart: down up

rebuild:
	docker compose build --no-cache
	docker compose up -d

ping:
	@echo "Checking service health..."
	@curl -sf http://localhost:8000/health || echo "Kong: not ready"
	@curl -sf http://localhost:8086/health || echo "IAM: not ready"
	@curl -sf http://localhost:8087/health || echo "Hardware: not ready"
	@curl -sf http://localhost:8088/health || echo "Analytics: not ready"
	@curl -sf http://localhost:8089/health || echo "Weather: not ready"
	@curl -sf http://localhost:8091/health || echo "Notification: not ready"

test:
	@cd services/iam-service && go test -v ./...
	@cd services/hardware-service && go test -v ./...
	@cd services/analytics-service && go test -v ./...
	@cd services/weather-service && go test -v ./...
	@cd services/notification-service && go test -v ./...

lint:
	golangci-lint run ./...
	@cd client && npm run lint

# ── CI/CD & Production ─────────────────────────────────────────────

ci: lint test
	@echo "CI checks passed"

infra:
	@echo "Deploying infrastructure via Bicep..."
	@az deployment group create --resource-group agriwizard-prod-rg --template-file infra/main.bicep

deploy:
	@echo "Deploying latest images to Azure..."
	@./scripts/deploy.sh

rollback:
	@echo "Rolling back to previous revision..."
	@./scripts/rollback.sh

health:
	@./scripts/healthcheck.sh http://localhost:8080

mqtt-check:
	@./scripts/test-mqtt-connectivity.sh $${MQTT_HOST} $${MQTT_PORT} $${MQTT_USERNAME} $${MQTT_PASSWORD}

logs-prod:
	@az containerapp logs show --name agriwizard-kong --resource-group agriwizard-prod-rg --follow