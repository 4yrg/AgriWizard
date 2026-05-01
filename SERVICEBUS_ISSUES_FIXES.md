# Azure Service Bus Communication - Implementation Fixes

**Branch:** `fix/servicebus-communication-investigation`

---

## Fix #1: Add Service Bus Notification Publisher to Analytics Service

### File: `services/analytics-service/servicebus.go`
**Status:** NEEDS CREATION (currently only has consumer)

Create a new publisher alongside the existing consumer:

```go
// ─────────────────────────────────────────────
// Azure Service Bus Notification Publisher
// ─────────────────────────────────────────────

type AzureServiceBusNotificationPublisher struct {
	client    *azservicebus.Client
	topicName string
	connected bool
	sender    *azservicebus.Sender
}

func NewAzureServiceBusNotificationPublisher(connectionString, topicName string) (*AzureServiceBusNotificationPublisher, error) {
	if connectionString == "" {
		log.Println("[WARN] Azure Service Bus connection string not provided, running without Service Bus notification publisher")
		return &AzureServiceBusNotificationPublisher{connected: false}, nil
	}

	client, err := azservicebus.NewClientFromConnectionString(connectionString, nil)
	if err != nil {
		log.Printf("[WARN] Failed to create Service Bus client for notifications: %v", err)
		return &AzureServiceBusNotificationPublisher{connected: false}, nil
	}

	sender, err := client.NewSender(topicName, nil)
	if err != nil {
		log.Printf("[WARN] Failed to create Service Bus sender for notifications: %v", err)
		client.Close(context.TODO())
		return &AzureServiceBusNotificationPublisher{connected: false}, nil
	}

	log.Printf("[INFO] Azure Service Bus notification publisher connected, topic: %s", topicName)

	return &AzureServiceBusNotificationPublisher{
		client:    client,
		topicName: topicName,
		sender:    sender,
		connected: true,
	}, nil
}

// PublishNotification sends a notification request to the Service Bus notifications topic
func (p *AzureServiceBusNotificationPublisher) PublishNotification(ctx context.Context, req NotificationRequest) error {
	if !p.connected || p.sender == nil {
		log.Println("[DEBUG] Azure Service Bus notification publisher not connected, skipping publish")
		return nil
	}

	body, err := json.Marshal(req)
	if err != nil {
		return err
	}

	message := &azservicebus.Message{
		Body:        body,
		ContentType: stringPtr("application/json"),
	}

	err = p.sender.SendMessage(ctx, message, nil)
	if err != nil {
		log.Printf("[ERROR] Azure Service Bus notification publish failed: %v", err)
		return err
	}

	log.Printf("[DEBUG] Published notification to Service Bus: channel=%s recipient=%s topic=%s",
		req.Channel, req.Recipient, p.topicName)
	return nil
}

func (p *AzureServiceBusNotificationPublisher) IsConnected() bool {
	return p.connected
}

func (p *AzureServiceBusNotificationPublisher) Close() error {
	if p.sender != nil {
		p.sender.Close(context.TODO())
	}
	if p.client != nil {
		return p.client.Close(context.TODO())
	}
	return nil
}

// Environment variable getters for notification topic/subscription
func getServiceBusNotificationConnection() string {
	return getEnv("SERVICE_BUS_CONNECTION", "")
}

func getServiceBusNotificationTopic() string {
	return getEnv("SERVICE_BUS_NOTIFICATIONS_TOPIC", "notifications")
}
```

### Add NotificationRequest type if missing in models.go:
```go
// NotificationRequest represents a notification to be sent
type NotificationRequest struct {
	UserID    string            `json:"user_id"`
	Channel   string            `json:"channel"` // "email", "sms", "push"
	Recipient string            `json:"recipient"` // email or phone number
	Subject   string            `json:"subject"`
	Message   string            `json:"message"`
	Data      map[string]string `json:"data,omitempty"`
	Timestamp time.Time         `json:"timestamp"`
}
```

---

## Fix #2: Initialize Publisher in Analytics Service Main

### File: `services/analytics-service/main.go`

**Update the main function to initialize the notification publisher:**

```go
var (
	rmqConsumer *RabbitMQConsumer
	sbConsumer *AzureServiceBusConsumer
	sbNotificationPublisher *AzureServiceBusNotificationPublisher  // ADD THIS
)

func main() {
	// ... existing code ...

	serviceBusConnection := getServiceBusConnection()
	serviceBusTopic := getServiceBusTopic()
	serviceBusSubscription := getServiceBusSubscription()
	serviceBusNotificationTopic := getServiceBusNotificationTopic()  // ADD THIS

	// ... existing code ...

	// Initialize Service Bus consumer (telemetry)
	sbConsumer, err = NewAzureServiceBusConsumer(serviceBusConnection, serviceBusTopic, serviceBusSubscription, h)
	if err != nil {
		log.Printf("[WARN] Azure Service Bus consumer initialization failed: %v", err)
	}

	// Initialize Service Bus notification publisher  // ADD THIS BLOCK
	sbNotificationPublisher, err = NewAzureServiceBusNotificationPublisher(serviceBusConnection, serviceBusNotificationTopic)
	if err != nil {
		log.Printf("[WARN] Azure Service Bus notification publisher initialization failed: %v", err)
	}

	// Store publisher in handler for use in automation
	h.SetNotificationPublisher(sbNotificationPublisher)  // ADD THIS

	// ... rest of the code ...
}
```

---

## Fix #3: Add Publisher to Handler and Update Handlers

### File: `services/analytics-service/handlers.go`

**Update Handler struct:**
```go
type Handler struct {
	status                      *ServiceStatus
	jwtSecret                   string
	hardwareURL                 string
	weatherURL                  string
	sbNotificationPublisher    *AzureServiceBusNotificationPublisher  // ADD THIS
}

// NewHandler creates a new Handler
func NewHandler(status *ServiceStatus, jwtSecret, hardwareURL, weatherURL string) *Handler {
	return &Handler{
		status:      status,
		jwtSecret:   jwtSecret,
		hardwareURL: hardwareURL,
		weatherURL:  weatherURL,
	}
}

// SetNotificationPublisher sets the Service Bus notification publisher
func (h *Handler) SetNotificationPublisher(pub *AzureServiceBusNotificationPublisher) {
	h.sbNotificationPublisher = pub
}
```

**Update ProcessIngest to publish notifications:**
```go
// In ProcessIngest function, update the decision trigger section (around line 306-319)
// BEFORE:
decisions = append(decisions, AutomationDecision{
    EquipmentID: equipID,
    Action:      action,
    Reason:      fmt.Sprintf("%s [scale=%.2f]", reason, scaleFactor),
})
// Dispatch command to hardware service
go h.dispatchHardwareCommand(equipID, action)

// AFTER:
decisions = append(decisions, AutomationDecision{
    EquipmentID: equipID,
    Action:      action,
    Reason:      fmt.Sprintf("%s [scale=%.2f]", reason, scaleFactor),
})
// Dispatch command to hardware service
go h.dispatchHardwareCommand(equipID, action)
// Publish notification for the event
go h.publishAutomationNotification(reading.ParameterID, reading.Value, action, reason)
```

**Add new method to Handler:**
```go
// publishAutomationNotification sends a notification about triggered automation
func (h *Handler) publishAutomationNotification(paramID string, value float64, action, reason string) {
	if h.sbNotificationPublisher == nil || !h.sbNotificationPublisher.IsConnected() {
		log.Printf("[DEBUG] Notification publisher not available, skipping notification")
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	req := NotificationRequest{
		Channel:   "email",
		Subject:   fmt.Sprintf("Automation Alert: %s", action),
		Message:   fmt.Sprintf("Action '%s' triggered for parameter %s. Value: %.2f. Reason: %s", action, paramID, value, reason),
		Timestamp: time.Now().UTC(),
		Data: map[string]string{
			"parameter_id": paramID,
			"action":       action,
			"value":        fmt.Sprintf("%.2f", value),
		},
	}

	if err := h.sbNotificationPublisher.PublishNotification(ctx, &req); err != nil {
		log.Printf("[ERROR] Failed to publish automation notification: %v", err)
	}
}
```

**Update health check to include notification publisher status:**
```go
r.GET("/health", func(c *gin.Context) {
	s := "ok"
	if !status.IsReady() {
		s = "starting"
	}
	c.JSON(http.StatusOK, gin.H{
		"status":           s,
		"service":          "analytics-service",
		"db_ready":         status.IsReady(),
		"migrated":         status.migrated,
		"rmq_ready":        rmqConsumer != nil && rmqConsumer.IsConnected(),
		"sb_consumer":      sbConsumer != nil && sbConsumer.IsConnected(),
		"sb_publisher":     sbNotificationPublisher != nil && sbNotificationPublisher.IsConnected(),  // ADD THIS
	})
})
```

---

## Fix #4: Improve Context Handling in Service Bus Consumers

### File: `services/analytics-service/servicebus.go`

**Update the Start() method with proper timeout handling:**

```go
func (c *AzureServiceBusConsumer) Start(ctx context.Context) error {
	if !c.connected || c.receiver == nil {
		log.Println("[DEBUG] Azure Service Bus not connected, skipping consumer start")
		close(c.ready)
		return nil
	}

	close(c.ready)
	log.Printf("[INFO] Azure Service Bus consumer started, listening on topic=%s subscription=%s", c.topicName, c.subscription)

	for {
		select {
		case <-ctx.Done():
			log.Println("[INFO] Azure Service Bus consumer shutting down")
			return nil
		default:
			// Use a short timeout to ensure responsiveness to context cancellation
			receiveCtx, cancel := context.WithTimeout(ctx, 30*time.Second)  // IMPROVED
			messages, err := c.receiver.ReceiveMessages(receiveCtx, 1, nil)
			cancel()  // IMPROVED
			
			if err != nil {
				// Check if it's a context timeout (expected behavior)
				if errors.Is(err, context.DeadlineExceeded) {
					// Continue to next iteration to check ctx.Done()
					continue
				}
				log.Printf("[ERROR] Failed to receive messages: %v", err)
				continue
			}

			for _, msg := range messages {
				if err := c.processMessage(ctx, msg); err != nil {
					log.Printf("[ERROR] Failed to process message: %v", err)
					_ = c.receiver.AbandonMessage(ctx, msg, nil)
				} else {
					_ = c.receiver.CompleteMessage(ctx, msg, nil)
				}
			}
		}
	}
}
```

Add import at top of file:
```go
import (
	// ... existing imports ...
	"errors"
)
```

### Same fix for `services/notification-service/servicebus.go`:

Apply the same context timeout handling to the notification consumer's Start() method.

---

## Fix #5: Add Configuration Validation

### File: `services/analytics-service/main.go`

Add validation function before consumer initialization:

```go
// ValidateServiceBusConfig checks that Service Bus configuration is properly set
func ValidateServiceBusConfig(connectionString string) error {
	if connectionString == "" {
		log.Println("[WARN] SERVICE_BUS_CONNECTION not set - running without Azure Service Bus")
		return nil // Not required for local development
	}

	if !strings.Contains(connectionString, "Endpoint=") {
		return fmt.Errorf("invalid SERVICE_BUS_CONNECTION format: missing Endpoint")
	}

	if !strings.Contains(connectionString, "SharedAccessKey") {
		return fmt.Errorf("invalid SERVICE_BUS_CONNECTION format: missing SharedAccessKey")
	}

	log.Println("[INFO] Service Bus configuration validated")
	return nil
}

// In main() function:
if err := ValidateServiceBusConfig(serviceBusConnection); err != nil {
	log.Printf("[ERROR] Service Bus configuration invalid: %v", err)
	// Don't fatal - allow fallback to RabbitMQ
}
```

---

## Fix #6: Standardize Environment Variables

### File: Update all service main.go files

Create a consistent pattern across all services. Use these environment variable names:

**For Telemetry Topic (hardware → analytics):**
```go
SERVICE_BUS_CONNECTION                    // Connection string
SERVICE_BUS_TELEMETRY_TOPIC              // Topic name (default: "telemetry")
SERVICE_BUS_ANALYTICS_SUBSCRIPTION        // Subscription name (default: "analytics-service")
```

**For Notifications Topic (analytics → notification):**
```go
SERVICE_BUS_CONNECTION                    // Same connection string
SERVICE_BUS_NOTIFICATIONS_TOPIC          // Topic name (default: "notifications")
SERVICE_BUS_NOTIFICATION_SUBSCRIPTION    // Subscription name (default: "notification-service")
```

### File: `services/analytics-service/servicebus.go`

```go
func getServiceBusTelemetryTopic() string {
	return getEnv("SERVICE_BUS_TELEMETRY_TOPIC", "telemetry")
}

func getServiceBusAnalyticsSubscription() string {
	return getEnv("SERVICE_BUS_ANALYTICS_SUBSCRIPTION", "analytics-service")
}

func getServiceBusNotificationsTopic() string {
	return getEnv("SERVICE_BUS_NOTIFICATIONS_TOPIC", "notifications")
}

func getServiceBusNotificationSubscription() string {
	return getEnv("SERVICE_BUS_NOTIFICATION_SUBSCRIPTION", "notification-service")
}
```

### File: `docker-compose.yml`

Add Service Bus environment variables to each service:

```yaml
analytics-service:
  environment:
    # ... existing ...
    SERVICE_BUS_CONNECTION: ""  # Empty in local dev (RabbitMQ fallback)
    SERVICE_BUS_TELEMETRY_TOPIC: "telemetry"
    SERVICE_BUS_ANALYTICS_SUBSCRIPTION: "analytics-service"
    SERVICE_BUS_NOTIFICATIONS_TOPIC: "notifications"
    SERVICE_BUS_NOTIFICATION_SUBSCRIPTION: "notification-service"

notification-service:
  environment:
    # ... existing ...
    SERVICE_BUS_CONNECTION: ""  # Empty in local dev
    SERVICE_BUS_NOTIFICATIONS_TOPIC: "notifications"
    SERVICE_BUS_NOTIFICATION_SUBSCRIPTION: "notification-service"

hardware-service:
  environment:
    # ... existing ...
    SERVICE_BUS_CONNECTION: ""  # Empty in local dev
    SERVICE_BUS_TELEMETRY_TOPIC: "telemetry"
```

---

## Fix #7: Update .env.example

### File: `.env.example`

Add clearly documented Service Bus configuration:

```bash
# ─────────────────────────────────────────────
# Azure Service Bus (Production)
# ─────────────────────────────────────────────
# Format: Endpoint=sb://namespace.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=...
# Get from: Azure Portal → Service Bus → Shared access policies → RootManageSharedAccessKey → Connection string
SERVICE_BUS_CONNECTION=

# Telemetry Topics (Hardware → Analytics)
SERVICE_BUS_TELEMETRY_TOPIC=telemetry
SERVICE_BUS_ANALYTICS_SUBSCRIPTION=analytics-service

# Notification Topics (Analytics → Notification)
SERVICE_BUS_NOTIFICATIONS_TOPIC=notifications
SERVICE_BUS_NOTIFICATION_SUBSCRIPTION=notification-service
```

---

## Testing Checklist

After implementing fixes:

- [ ] Analytics service initializes notification publisher successfully
- [ ] Health check shows notification publisher as connected when SERVICE_BUS_CONNECTION is set
- [ ] When telemetry triggers automation rule, notification is published to Service Bus
- [ ] Notification service receives the notification message
- [ ] Notification service processes and sends email
- [ ] Context timeout works correctly (messages still received even if one hangs)
- [ ] Graceful shutdown: consumers/publishers properly closed
- [ ] Local dev works without Service Bus (RabbitMQ fallback)
- [ ] Production deployment with Service Bus works end-to-end

---

## Summary of Changes

| Component | Fix | Impact |
|-----------|-----|--------|
| Analytics Service | Add notification publisher | Enables notification publishing |
| Analytics Handler | Call publishAutomationNotification() | Notifications triggered on automation |
| Service Bus Consumer | Add context timeout | Prevents hangs, improves responsiveness |
| Configuration | Standardize env variables | Reduces errors, improves consistency |
| Documentation | Update .env.example | Clearer setup instructions |

All fixes are backward compatible and include fallback mechanisms for local development without Azure Service Bus.
