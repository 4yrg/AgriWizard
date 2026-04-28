# AgriWizard — Security Design

## Overview

Enterprise-grade security implementation for AgriWizard on Azure.

---

## Security Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                     Security Layers                                │
├────────────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────┐                                          │
│  │  1. Edge Security │  ← Front Door + WAF + DDoS              │
│  └────────┬─────────┘                                          │
│           │                                                    │
│  ┌────────┴─────────┐                                         │
│  │  2. API Security  │  ← APIM + JWT + Rate Limiting           │
│  └────────┬─────────┘                                          │
│           │                                                    │
│  ┌────────┴─────────┐                                        │
│  │  3. Network      │  ← VNET + Private Endpoints + NSGs     │
│  └────────┬─────────┘                                          │
│           │                                                    │
│  ┌────────┴─────────┐                                          │
│  │  4. App Security │  ← Managed Identity + Key Vault       │
│  └────────┬─────────┘                                          │
│           │                                                    │
│  ┌────────┴─────────┐                                          │
│  │  5. Data Security│  ← Encryption + DB Security         │
│  └──────────────────┘                                          │
│                                                                 │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 1. Edge Security

### Azure Front Door with WAF

```hcl
# WAF Policy
resource "azurerm_web_application_firewall_policy" "main" {
  name                = "agriwizard-waf"
  resource_group_name = azurerm_resource_group.main.name
  location           = azurerm_resource_group.main.location

  rule {
    name      = "SQLInjection"
    action   = "Block"
    priority = 1
    rule_type = "Microsoft_BotManagerRuleGroup"
    enabled  = true
  }
}

# WAF rules for OWASP Top 10
# - SQL Injection
# - XSS
# - Local File Inclusion
# - Command Injection
# - CVE protections
```

### DDoS Protection

- Azure DDoS Network Protection (Standard tier)
- Automatic mitigation
- Always-on monitoring

### TLS/SSL

| Component | Certificate | Management |
|----------|-------------|------------|
| Front Door | App Service Certificate | Auto-renewal |
| APIM | Built-in or App Service | Managed |
| IoT Hub | Managed Identity | Auto-renewal |

---

## 2. API Security

### JWT Validation

```yaml
# API Management Policy
<policies>
  <inbound>
    <validate-jwt header-name="Authorization">
      <openid-config url="https://login.microsoftonline.com/{tenant}/v2.0/.well-known/openid-configuration" />
      <audiences>
        <audience>agriwizard-iam</audience>
      </audiences>
      <issuers>
        <issuer>agriwizard-iam</issuer>
      </issuers>
      <signature-check>
        <key>agrivault:jwt-secret</key>
      </signature-check>
    </validate-jwt>
  </inbound>
</policies>
```

### Rate Limiting

| Tier | Requests | Period |
|------|----------|--------|
| Anonymous | 100 | 1 minute |
| Authenticated | 500 | 1 minute |
| Premium | 2000 | 1 minute |

### CORS Configuration

```yaml
<cors>
  <allowed-origins>
    <origin>https://agriwizard.com</origin>
    <origin>https://www.agriwizard.com</origin>
  </allowed-origins>
  <allowed-methods>
    <method>GET</method>
    <method>POST</method>
    <method>PUT</method>
    <method>DELETE</method>
  </allowed-methods>
  <allowed-headers>
    <header>Authorization</header>
    <header>Content-Type</header>
  </allowed-headers>
</cors>
```

---

## 3. Network Security

### Virtual Network Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                Virtual Network (10.0.0.0/16)              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Subnet: App (10.0.1.0/24)     → Container Apps             │
│  Subnet: Api (10.0.2.0/24)    → APIM VNet injection      │
│  Subnet: Data (10.0.3.0/24)  → Private Endpoints         │
│  Subnet: Gateway (10.0.4.0/24) → VPN/ExpressRoute         │
│  Subnet: AzureBastion (10.0.5.0/24) → Bastion           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Network Security Groups

| Inbound Rules | Source | Destination | Port | Action |
|--------------|--------|--------------|------|--------|
| Allow APIM | APIM Subnet | App Subnet | 80,443 | Allow |
| Allow App to DB | App Subnet | Data Subnet | 5432 | Allow |
| Allow App to SB | App Subnet | Data Subnet | 5671,5672 | Allow |
| Deny All | Any | Any | Any | Deny |

### Private Endpoints

| Service | Private Endpoint |
|--------|---------------|
| PostgreSQL | postgres.postgres.database.azure.com |
| Key Vault | vault.azure.net |
| Storage | blob.core.windows.net |
| Service Bus | servicebus.windows.net |

---

## 4. Application Security

### Managed Identities

```hcl
# Container Apps System MSI
resource "azurerm_user_assigned_identity" "container_apps" {
  name                = "agriwizard-apps-mi"
  resource_group_name = azurerm_resource_group.main.name
  location           = azurerm_resource_group.main.location
}
```

| Identity | Type | Purpose |
|----------|------|---------|
| Container Apps | System-assigned | Access Key Vault |
| APIM | System-assigned | Access Key Vault |
| Terraform | User-assigned | Deploy infrastructure |

### Key Vault RBAC

| Role | Permissions |
|------|-------------|
| Reader | Get, List secrets |
| Contributor | All secrets operations |
| Admin | Full access + manage |

```hcl
# Key Vault Access Policy
resource "azurerm_key_vault_access_policy" "container_apps" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id   = data.azurerm_client_config.current.tenant_id
  object_id  = azurerm_container_app.iam.identity[0].principal_id

  secret_permissions = ["Get", "List"]
  key_permissions   = ["Get", "List"]
}
```

### Secrets Rotation

| Secret | Rotation | Frequency |
|--------|----------|-----------|
| JWT Secret | Manual + Key Vault | 90 days |
| DB Password | Terraform | 30 days |
| Storage Key | Manual | 90 days |
| IoT Hub | Manual | 90 days |

---

## 5. Data Security

### Encryption

| Data Type | At Rest | In Transit |
|----------|--------|------------|
| PostgreSQL | AES-256 | TLS 1.2 |
| Storage | AES-256 | TLS 1.2 |
| Key Vault | AES-256 | TLS 1.2 |
| Service Bus | AES-256 | TLS 1.2 |

### Database Security

```sql
-- Create read-only role
CREATE ROLE agriwizard_ro WITH LOGIN PASSWORD '...';
GRANT CONNECT ON DATABASE agriwizard TO agriwizard_ro;
GRANT USAGE ON SCHEMA iam TO agriwizard_ro;
GRANT SELECT ON iam.users TO agriwizard_ro;
```

### Audit Logging

```hcl
# Enable auditing
resource "azurerm_mssql_database_extended_auditing_policy" "main" {
  database_id = azurerm_mssql_database.main.id
  storage_endpoint = azurerm_storage_account.main.primary_blob_endpoint
  storage_account_access_key = azurerm_storage_account.main.primary_access_key
  retention_days = 90
}
```

---

## 6. Zero Trust

### Service-to-Service Communication

```
┌────────────────────────────────────────────┐
│       Zero Trust Implementation          │
├────────────────────────────────────────────┤
│                                             │
│  ┌──────────────�    ┌──────────────┐       │
│  │    Front    │───►│     APIM    │       │
│  │   Door     │    │  (Validate)│       │
│  └──────────────┘    └──────┬───────┘       │
│                             │              │
│  ┌─────────────────────────┴──────────┐   │
│  │  Container Apps Environment        │   │
│  │  (Internal ingress only)            │   │
│  └─────────────────────────┬───────────┘   │
│                          │              │
│  ┌───────────┬───────┬────────┬───────┐    │
│  │    IAM   │Hardware│Analytics│Weather│    │
│  │  (mTLS)  │ (mTLS)│  (mTLS) │ (mTLS)│   │
│  └─────────┴───────┴────────┴───────┘    │
│                          │              │
│  ┌───────────────────────┴──────────┐    │
│  │   Azure Services                  │    │
│  │  (Private Endpoints)            │    │
│  └───────────────────────────────┘    │
└────────────────────────────────────────┘
```

### mTLS between Services

- Container Apps can use internal ingress
- All inter-service calls via internal FQDN
- Optional: Service Mesh for mTLS

---

## 7. RBAC

### Role Assignments

| Principal | Role | Scope |
|-----------|------|-------|
| Dev Team | Contributor | Resource Group |
| DevOps | Owner | Subscription |
| CI/CD | Contributor | Resource Group |
| Monitoring | Reader | Resource Group |
| Support | Support Request | Subscription |

---

## 8. Security Checklist

- [ ] Enable Azure AD authentication
- [ ] Configure MFA for all users
- [ ] Set up Key Vault with RBAC
- [ ] Deploy WAF policy
- [ ] Configure TLS 1.2+ everywhere
- [ ] Enable Private Link endpoints
- [ ] Configure NSGs
- [ ] Enable audit logging
- [ ] Set up alerts for suspicious activity
- [ ] Implement JWT validation
- [ ] Configure rate limiting
- [ ] Enable DDoS protection
- [ ] Set up backup and recovery
- [ ] Document incident response plan
- [ ] Run security assessments

---

## 9. Monitoring & Alerts

### Security Events

| Event | Alert | Action |
|------|------|--------|
| Failed login attempts > 10 | Critical | Notify SOC |
| Unusual API traffic | Warning | Review |
| Key Vault access | Info | Log |
| DB query errors | Warning | Investigate |
| Deployments | Info | Notify channel |

### Log Analytics Queries

```kusto
// Failed authentication
AzureActivity
| where ResourceProvider == "Microsoft.ApiManagement"
| where OperationNameValue == "Microsoft.ApiManagement/SignedIn"
| where _ActivityStatus == "Failure"
```