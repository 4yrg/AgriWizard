# AgriWizard — Azure Cost Plans

## Overview

Three pricing tiers for different scale requirements.

---

## Pricing Summary

| Component | MVP | Growing | Enterprise |
|-----------|-----|---------|-----------|
| **Container Apps** | $12/mo | $45/mo | $150/mo |
| **API Management** | $50/mo | $50/mo | $550/mo |
| **PostgreSQL** | $0* | $75/mo | $150/mo |
| **Service Bus** | $0* | $25/mo | $100/mo |
| **IoT Hub** | $0* | $25/mo | $50/mo |
| **Storage** | $5/mo | $15/mo | $50/mo |
| **Key Vault** | $0* | $0* | $0* |
| **App Insights** | $0* | $0* | $0* |
| **Front Door** | $20/mo | $20/mo | $75/mo |
| **Total** | **~$87/mo** | **~$255/mo** | **~$1,175/mo** |

*_Free tier or within free limits_

---

## Plan 1: MVP / Small Farm

**Target**: Single greenhouse, up to 100 devices

### Services

| Service | Tier | Cost |
|--------|------|------|
| Container Apps | Consumption | $12* |
| API Management | Developer | $50 |
| PostgreSQL Flexible | Burstable (Free*) | $0 |
| Service Bus | Standard | $0 |
| IoT Hub | Free (F1) | $0 |
| Storage | LRS | $5 |
| Key Vault | Standard | $0 |
| App Insights | Pay-as-you-go | $0 |
| Front Door | Standard | $20 |

*Container Apps pay-per-use, ~$0.000012/vCPU-sec

### Monthly Estimate: **$87**

```
Breakdown:
  APIM Developer:     $50.00
  Container Apps:    $12.00
  Front Door:       $20.00
  Storage:          $5.00
  ─────────────────────────
  Total:           $87.00
```

### What's Included

- Up to 500 IoT devices
- 8,000 IoT Hub messages/day
- 5 container apps
- Basic API management
- Regional storage

### Tradeoffs

- ❌ No HA (single region)
- ❌ Limited scaling
- ❌ Basic IoT features
- ❌ No WAF on Front Door
- ✓ Free tier IoT Hub

---

## Plan 2: Growing Commercial

**Target**: 2-3 greenhouses, 500-2000 devices

### Services

| Service | Tier | Cost |
|--------|------|------|
| Container Apps | Dedicated | $45 |
| API Management | Developer | $50 |
| PostgreSQL Flexible | GeneralPurpose | $75 |
| Service Bus | Standard | $25 |
| IoT Hub | S1 | $25 |
| Storage | ZRS | $15 |
| Key Vault | Standard | $0 |
| App Insights | Pay-as-you-go | $0 |
| Front Door | Standard | $20 |

### Monthly Estimate: **$255**

```
Breakdown:
  Container Apps:    $45.00
  APIM Developer:    $50.00
  PostgreSQL:       $75.00
  Service Bus:      $25.00
  IoT Hub S1:      $25.00
  Front Door:       $20.00
  Storage:         $15.00
  ─────────────────────────
  Total:          $255.00
```

### What's Included

- Up to 2,000 IoT devices
- 400K IoT Hub messages/day
- 5 container apps with scaling
- Zone-redundant PostgreSQL
- Standard messaging

### Tradeoffs

- ✓ Zone-redundant DB
- ✓ Auto-scaling containers
- ✓ Better IoT features
- ❌ Standard APIM only
- ❌ No WAF

---

## Plan 3: Enterprise Multi-Site

**Target**: Multiple locations, 5000+ devices, enterprise SLA

### Services

| Service | Tier | Cost |
|--------|------|------|
| Container Apps | Dedicated | $150 |
| API Management | Premium | $550 |
| PostgreSQL Flexible | BusinessCritical | $150 |
| Service Bus | Premium | $100 |
| IoT Hub | S2 | $50 |
| Storage | GRS | $50 |
| Key Vault | Premium | $0 |
| App Insights | Pay-as-you-go | $0 |
| Front Door | Premium | $75 |

### Monthly Estimate: **$1,175**

```
Breakdown:
  APIM Premium:    $550.00
  Container Apps:   $150.00
  PostgreSQL:       $150.00
  Service Bus:     $100.00
  IoT Hub S2:       $50.00
  Front Door:       $75.00
  Storage:         $50.00
  ───────────────────���─────
  Total:        $1,175.00
```

### What's Included

- Unlimited IoT devices
- 6M IoT Hub messages/day
- 10 container apps
- Global redundancy
- WAF + DDoS protection
- Enterprise RBAC

### Features

- ✓ Global redundancy
- ✓ Enterprise security
- ✓ WAF protection
- ✓ Premium IoT features
- ✓ 99.99% SLA available

---

## Cost Optimization Tips

### 1. Container Apps Scaling

```hcl
# Scale to zero for weather service
scaling {
  min_replicas = 0
  max_replicas = 2
}
# Only pay when used
```

### 2. IoT Hub Message Batching

- Batch messages from devices
- Use 4KB message size
- Reduces message count

### 3. Storage Tiers

- Hot: Recent data
- Cool: 30+ days
- Archive: 90+ days

### 4. Free Tier Usage

| Service | Free Allowance |
|---------|--------------|
| IoT Hub F1 | 8K messages/day |
| PostgreSQL | 1 year free (burstable) |
| Service Bus | 1 year Standard |
| Key Vault | 10K secret ops |
| App Insights | 1GB/month |

### 5. Reserving Compute

```hcl
# Dedicated CPU reservation
# Save ~40% vs pay-per-use
reserved_cpu:
  core_count: 4
  duration: 1year
```

---

## Cost Comparison by Year

| Year | MVP | Growing | Enterprise |
|------|-----|---------|-----------|
| 1 | $1,044 | $3,060 | $14,100 |
| 2 | $1,044 | $3,060 | $14,100 |
| 3 | $1,044 | $3,060 | $14,100 |
| **Total** | **$3,132** | **$9,180** | **$42,300** |

---

## Scaling Roadmap

```
Cost
  ^
$2K |                                    ───── Enterprise
$1K |                            ──── Growing
$500 |                    ──── MVP
    └──────────────────────────────────────────►
         100    500    1K    5K    10K Devices
```

---

## Budget Alerts

Set up budget alerts in Azure Cost Management:

```
Alert 1: 80% budget - Email to team
Alert 2: 100% budget - Email + SMS to lead
Alert 3: 120% budget - Email + SMS to manager
```

---

## Ways to Reduce Costs

| Optimization | Savings |
|--------------|---------|
| Use Free tier IoT Hub | $25/mo |
| Scale-to-zero for weather | $5/mo |
| Use Basic tier PostgreSQL | $50/mo |
| Use Standard tier APIM | Already low |
| Enable compression | 20% bandwidth |
| Use reserved instances | 40% compute |

---

## Next Steps

1. Start with MVP plan
2. Monitor usage monthly
3. Upgrade tiers as needed
4. Use budget alerts
5. Optimize scaling rules