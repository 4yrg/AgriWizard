# Azure Service Bus Communication Issues - Investigation Report

**Branch:** `fix/servicebus-communication-investigation`
**Date:** 2026-05-01

## Summary
Identified 5 critical issues preventing proper inter-service communications via Azure Service Bus:

---

## Issue #1: Missing Service Bus Publisher in Analytics Service
**Severity:** HIGH  
**File:** [services/analytics-service/main.go](services/analytics-service/main.go)

### Problem
Analytics service **consumes telemetry** but does **not publish notifications** to the Service Bus. When automation rules are triggered, notifications should be published to the `notifications` topic for the notification service to consume, but there's no publisher configured.

### Current Flow
- Analytics processes telemetry and triggers automation rules ✓
- Dispatches control commands to hardware service via HTTP ✓
- **BUT:** No notifications are sent to the notification service via Service Bus ✗

### Expected Flow
- Telemetry → Analytics (via Service Bus) ✓
- Automation Rules Triggered → Publish notifications to `notifications` topic ✗ MISSING
- Notification Service Consumes → Sends emails/notifications ✓

### Impact
- Notifications are never sent even when automation rules are triggered
- The notification service consumer is idle and waiting for messages that never come

---

## Issue #2: Analytics Service Missing Notification Publisher Implementation
**Severity:** HIGH  
**File:** `services/analytics-service/` - Missing `servicebus.go` publisher

### Problem
While analytics-service has a **consumer** in `servicebus.go`, it lacks a **publisher** to send notifications. The handlers.go file references `dispatchHardwareCommand()` but there's no equivalent `publishNotification()` function.

### Evidence
- Line 630-751 in handlers.go shows `ProcessIngest()` triggers automation decisions
- Decision triggers call `dispatchHardwareCommand()` for control only
- No call to publish notifications to the `notifications` topic

### Required Implementation
Need to create a notification publisher similar to hardware-service's publisher pattern:
```go
// Missing: Analytics Service Bus Notification Publisher
type AzureServiceBusNotificationPublisher struct {
    client    *azservicebus.Client
    topicName string
    connected bool
    sender    *azservicebus.Sender
}

func (p *AzureServiceBusNotificationPublisher) PublishNotification(ctx context.Context, req NotificationRequest) error {
    // Send to 'notifications' topic
}
```

---

## Issue #3: Incomplete Context Handling in Service Bus Consumers
**Severity:** MEDIUM  
**Files:** 
- [services/analytics-service/servicebus.go](services/analytics-service/servicebus.go#L60-L80)
- [services/notification-service/servicebus.go](services/notification-service/servicebus.go#L60-L80)

### Problem
The `Start()` method receives a context but **doesn't properly use it for timeouts** in message receiving.

### Current Code (analytics-service, line 68-76)
```go
for {
    select {
    case <-ctx.Done():
        // ...
    default:
        messages, err := c.receiver.ReceiveMessages(ctx, 1, nil)
        // No timeout handling for long-running receive
    }
}
```

### Issue
- If `ReceiveMessages()` hangs, the context won't timeout properly
- The receiver should use a timeout context within the receive loop
- Messages might never be received if context is not properly propagated

### Fix
Need to use a short timeout for receiving to ensure responsiveness:
```go
receiveCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
messages, err := c.receiver.ReceiveMessages(receiveCtx, 1, nil)
cancel()
```

---

## Issue #4: Missing Topic/Subscription Validation & Configuration Mismatch
**Severity:** MEDIUM  
**Files:**
- [services/notification-service/servicebus.go](services/notification-service/servicebus.go#L128-L131)
- [infra/modules/servicebus.bicep](infra/modules/servicebus.bicep)

### Problem
Topic and subscription names are hardcoded with defaults, but there's no validation that they exist in Service Bus.

### Current Code
```go
// notification-service/servicebus.go line 129-131
func getServiceBusNotificationTopic() string {
    return getEnv("SERVICE_BUS_TOPIC", "notifications")  // Default
}
```

### Issue
1. No validation that topic/subscription exists before consumer starts
2. If topic/subscription doesn't exist on Azure, consumer silently fails
3. Default values might not match actual Service Bus configuration
4. Error handling just logs warnings and continues with `connected: false`

### Example Failure Scenario
- Infrastructure creates topics: `telemetry`, `notifications`
- Service subscribes looking for: `telemetry` ✓, `notifications` ✓
- But if topics were named differently or deleted, consumers won't detect this until messages should arrive
- Service reports ready even though it's not actually connected

---

## Issue #5: Environment Variable Inconsistency Between Services
**Severity:** MEDIUM  
**Files:**
- [services/analytics-service/main.go](services/analytics-service/main.go#L65-L67)
- [services/notification-service/main.go](services/notification-service/main.go#L27-L30)
- [services/hardware-service/main.go](services/hardware-service/main.go#L79-L81)

### Problem
Each service independently reads Service Bus configuration with different patterns and no coordination.

### Current Pattern
**Hardware Service** (line 79-81, main.go):
```go
serviceBusConnection := getServiceBusConnection()      // Reads: SERVICE_BUS_CONNECTION
serviceBusTopic := getServiceBusTopic()               // Reads: SERVICE_BUS_TOPIC (default: "telemetry")
```

**Analytics Service** (line 65-67, main.go):
```go
serviceBusConnection := getServiceBusConnection()     // Reads: SERVICE_BUS_CONNECTION
serviceBusTopic := getServiceBusTopic()              // Reads: SERVICE_BUS_TOPIC (default: "telemetry")
serviceBusSubscription := getServiceBusSubscription() // Reads: SERVICE_BUS_SUBSCRIPTION (default: "analytics-service")
```

**Notification Service** (line 27-30, main.go):
```go
serviceBusConnection := getServiceBusNotificationConnection()  // DIFFERENT function
serviceBusTopic := getServiceBusNotificationTopic()           // DIFFERENT function
serviceBusSubscription := getServiceBusNotificationSubscription() // DIFFERENT function
```

### Issues
1. Notification service uses `*Notification*` prefixed getter functions - inconsistent naming
2. No validation that topics match the infrastructure setup
3. No configuration documentation or validation
4. If environment variable is missing, services silently degrade
5. Local docker-compose has no SERVICE_BUS_* variables set at all

### Missing in docker-compose.yml
```yaml
# These should be set but are not:
- SERVICE_BUS_CONNECTION=
- SERVICE_BUS_TOPIC=telemetry
- SERVICE_BUS_SUBSCRIPTION=analytics-service
```

---

## Issue #6: No Publisher for Notification Messages from Analytics
**Severity:** CRITICAL  
**File:** [services/analytics-service/handlers.go](services/analytics-service/handlers.go#L295-L330)

### Problem
When automation rules are triggered (ProcessIngest function), the code calls `dispatchHardwareCommand()` to control equipment, but **nowhere does it send a notification message**.

### Current Code (handlers.go, line 306-319)
```go
decisions = append(decisions, AutomationDecision{
    EquipmentID: equipID,
    Action:      action,
    Reason:      fmt.Sprintf("%s [scale=%.2f]", reason, scaleFactor),
})
// Dispatch command to hardware service
go h.dispatchHardwareCommand(equipID, action)  // Only this, no notification publishing
```

### What Should Happen
1. Automation decision is made (current ✓)
2. Command dispatched to hardware (current ✓)
3. **Notification message published** (MISSING ✗)
4. Notification service receives and sends email/SMS (would work if publisher existed)

### Example: User Should Get Alert
- Soil moisture drops below threshold
- Analytics detects LOW status
- Sends irrigation command ✓
- **Should ALSO send notification: "Irrigation activated - moisture was low"** ✗

---

## Root Cause Summary

| Issue | Root Cause | Impact |
|-------|-----------|--------|
| #1 | No notification publisher in analytics | Notifications never sent |
| #2 | Missing publisher implementation | Can't publish to Service Bus |
| #3 | Incomplete context usage | Potential message loss |
| #4 | No config validation | Silent failures |
| #5 | Inconsistent env variables | Configuration confusion |
| #6 | No notification dispatch call | Async notification flow broken |

---

## Service Communication Flow (Current vs. Expected)

### Current (Broken) Flow
```
Hardware → publishes telemetry → Service Bus ✓
          ↓
Analytics → consumes telemetry → Service Bus ✓
          ↓
Automation Rules Triggered
          ↓
Dispatch Control Command via HTTP ✓
          ↓
(Notifications never sent) ✗
```

### Expected Flow
```
Hardware → publishes telemetry → Service Bus ✓
          ↓
Analytics → consumes telemetry → Service Bus ✓
          ↓
Automation Rules Triggered
          ↓
├─ Dispatch Control Command via HTTP ✓
└─ Publish Notification → Service Bus ✗ MISSING
   ↓
Notification Service ← consumes from Service Bus
          ↓
Send Email/SMS ✓ (blocked by missing publisher)
```

---

## Next Steps
See `SERVICEBUS_ISSUES_FIXES.md` for detailed implementation fixes for all issues.
