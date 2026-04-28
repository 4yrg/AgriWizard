# AgriWizard — Migration Roadmap

## Summary

This document outlines the complete migration path from the current local-only deployment to a dual-environment (local + Azure production) architecture.

---

## Current State

- **Local Development**: Docker Compose with Kong, PostgreSQL, RabbitMQ, NATS
- **IoT**: HiveMQ Cloud
- **Frontend**: Next.js
- **Services**: 5 Go microservices (IAM, Hardware, Analytics, Weather, Notification)

---

## Target State

- **Local Development**: Docker Compose (improved developer experience)
- **Production**: Azure Container Apps + API Management + Managed Azure services

---

## Migration Phases

### Phase 0: Preparation (Week 1-2)

- [ ] Audit current infrastructure
- [ ] Estimate Azure costs
- [ ] Set up Azure subscription
- [ ] Create GitHub repository secrets
- [ ] Review security requirements

### Phase 1: Local Development (Week 2-3)

- [ ] Update docker-compose.yml (ports 8XXX)
- [ ] Add docker-compose.override.yml
- [ ] Create Makefile.dev
- [ ] Update .env.example
- [ ] Test local development flow

**Deliverables:**
- `docker-compose.yml`
- `docker-compose.override.yml`
- `Makefile.dev`
- `.env.example`

### Phase 2: Infrastructure as Code (Week 3-4)

- [ ] Create Terraform modules
- [ ] Define environment variables
- [ ] Test Terraform locally
- [ ] Create dev environment

**Deliverables:**
- `infrastructure/azure/terraform/`
- `environments/dev.tfvars`

### Phase 3: CI/CD Pipeline (Week 4-5)

- [ ] Create GitHub Actions workflow
- [ ] Add secrets to repository
- [ ] Test build pipeline
- [ ] Test deployment to dev

**Deliverables:**
- `.github/workflows/ci-cd.yml`

### Phase 4: Security (Week 5-6)

- [ ] Configure Key Vault
- [ ] Set up Managed Identities
- [ ] Configure WAF
- [ ] Enable logging

**Deliverables:**
- Security configuration in Terraform

### Phase 5: IoT Migration (Week 6-7)

- [ ] Create Azure IoT Hub
- [ ] Register devices
- [ ] Update Hardware Service
- [ ] Test MQTT integration

**Deliverables:**
- IoT Hub configuration
- Updated Hardware Service

### Phase 6: Production Migration (Week 7-8)

- [ ] Deploy to staging
- [ ] Run integration tests
- [ ] User acceptance testing
- [ ] Deploy to production

### Phase 7: Cutover (Week 8-9)

- [ ] Update DNS
- [ ] Monitor metrics
- [ ] Validate all services
- [ ] Decommission old services

---

## Rollback Plan

1. **Database**:Keep existing Aiven PostgreSQL until confirmed
2. **IoT**: Keep HiveMQ Cloud for 30 days
3. **DNS**: Use shorter TTL during migration
4. **Rollback Script**: 

```bash
# Rollback to local
export $(cat .env | xargs)
docker compose up -d
```

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|---------|---------|----------|
| Azure downtime | Low | High | Keep local as backup |
| Cost overrun | Medium | Medium | Budget alerts |
| IoT device issues | Medium | High | Keep HiveMQ |
| Integration issues | High | High | Test thoroughly |
| Learning curve | Medium | Low | Training docs |

---

## Success Criteria

- [ ] Local development works < 5 minutes
- [ ] Azure deploy < 30 minutes
- [ ] All tests pass
- [ ] Zero data loss
- [ ] < 1 hour downtime
- [ ] Cost within budget

---

## Timeline

```
Week:  1  2  3  4  5  6  7  8  9
       |  |  |  |  |  |  |  |  |
Prep   ███▓▓▓                              Phase 0
Local      ███▓▓▓                           Phase 1
IaC          ███▓▓▓                        Phase 2
CI/CD           ███▓▓▓                     Phase 3
Security           ███▓▓▓                  Phase 4
IoT                  ███▓▓▓               Phase 5
Prod                      ███▓▓▓▓▓▓▓       Phase 6
Cutover                         ███▓▓      Phase 7

Legend: ███ = Active  ▓▓▓ = Buffer
```

---

## Getting Started

### Prerequisites

- Azure subscription
- GitHub repository access
- Docker Desktop
- Go 1.26+

### Quick Start

1. **Clone repository**
   ```bash
   git clone https://github.com/agriwizard/agriwizard.git
   cd agriwizard
   ```

2. **Start local development**
   ```bash
   docker compose up -d
   make dev-start
   ```

3. **Deploy to Azure**
   ```bash
   cd infrastructure/azure/terraform
   terraform init
   terraform apply -var-file=environments/dev.tfvars
   ```

---

## Contact

- **Team**: team@agriwizard.com
- **Documentation**: docs.agriwizard.com
- **Support**: support@agriwizard.com