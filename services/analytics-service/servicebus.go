package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/messaging/azservicebus"
)

type AzureServiceBusConsumer struct {
	client       *azservicebus.Client
	topicName    string
	subscription string
	handler      *Handler
	connected    bool
	ready        chan struct{}
	receiver     *azservicebus.Receiver
}

type AzureServiceBusNotificationPublisher struct {
	client    *azservicebus.Client
	topicName string
	connected bool
	sender    *azservicebus.Sender
}

type NotificationRequest struct {
	Channel    string            `json:"channel"`
	Recipient  string            `json:"recipient"`
	TemplateID string            `json:"template_id,omitempty"`
	Variables  map[string]string `json:"variables,omitempty"`
	Subject    string            `json:"subject,omitempty"`
	Body       string            `json:"body,omitempty"`
	Metadata   map[string]string `json:"metadata,omitempty"`
}

func NewAzureServiceBusNotificationPublisher(connectionString, topicName string) (*AzureServiceBusNotificationPublisher, error) {
	if connectionString == "" {
		log.Println("[WARN] Azure Service Bus connection string not provided, running without Service Bus notification publisher")
		return &AzureServiceBusNotificationPublisher{connected: false}, nil
	}

	var client *azservicebus.Client
	var err error
	for i := 0; i < 10; i++ {
		client, err = azservicebus.NewClientFromConnectionString(connectionString, nil)
		if err == nil {
			sender, err := client.NewSender(topicName, nil)
			if err == nil {
				log.Printf("[INFO] Azure Service Bus notification publisher ready, topic: %s", topicName)
				return &AzureServiceBusNotificationPublisher{
					client:    client,
					topicName: topicName,
					connected: true,
					sender:    sender,
				}, nil
			}
			log.Printf("[WARN] Failed to create Service Bus notification sender (attempt %d/10): %v", i+1, err)
			client.Close(context.TODO())
		} else {
			log.Printf("[WARN] Failed to create Service Bus notification client (attempt %d/10): %v", i+1, err)
		}
		time.Sleep(5 * time.Second)
	}

	return &AzureServiceBusNotificationPublisher{connected: false}, fmt.Errorf("failed to connect to Azure Service Bus notification after 10 attempts: %v", err)
}

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

	if err := p.sender.SendMessage(ctx, message, nil); err != nil {
		log.Printf("[ERROR] Azure Service Bus notification publish failed: %v", err)
		return err
	}

	log.Printf("[DEBUG] Published automation notification to Service Bus: recipient=%s topic=%s", req.Recipient, p.topicName)
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

func NewAzureServiceBusConsumer(connectionString, topicName, subscription string, handler *Handler) (*AzureServiceBusConsumer, error) {
	if connectionString == "" {
		log.Println("[WARN] Azure Service Bus connection string not provided, running without Service Bus consumer")
		return &AzureServiceBusConsumer{connected: false, ready: make(chan struct{})}, nil
	}

	var client *azservicebus.Client
	var err error
	for i := 0; i < 10; i++ {
		client, err = azservicebus.NewClientFromConnectionString(connectionString, nil)
		if err == nil {
			receiver, err := client.NewReceiverForSubscription(topicName, subscription, nil)
			if err == nil {
				log.Printf("[INFO] Azure Service Bus consumer ready, topic: %s, subscription: %s", topicName, subscription)
				return &AzureServiceBusConsumer{
					client:       client,
					topicName:    topicName,
					subscription: subscription,
					handler:      handler,
					connected:    true,
					ready:        make(chan struct{}),
					receiver:     receiver,
				}, nil
			}
			log.Printf("[WARN] Failed to create Service Bus receiver (attempt %d/10): %v", i+1, err)
			client.Close(context.TODO())
		} else {
			log.Printf("[WARN] Failed to create Service Bus client (attempt %d/10): %v", i+1, err)
		}
		time.Sleep(5 * time.Second)
	}

	return &AzureServiceBusConsumer{connected: false, ready: make(chan struct{})}, fmt.Errorf("failed to connect to Azure Service Bus after 10 attempts: %v", err)
}

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
			receiveCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
			messages, err := c.receiver.ReceiveMessages(receiveCtx, 1, nil)
			cancel()
			if err != nil {
				if errors.Is(err, context.DeadlineExceeded) {
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

func (c *AzureServiceBusConsumer) processMessage(ctx context.Context, msg *azservicebus.ReceivedMessage) error {
	var event TelemetryEvent
	if err := json.Unmarshal(msg.Body, &event); err != nil {
		log.Printf("[ERROR] Failed to unmarshal telemetry event: %v", err)
		return err
	}

	log.Printf("[DEBUG] Received telemetry from Service Bus: sensor=%s param=%s value=%.2f",
		event.SensorID, event.ParameterID, event.Value)

	ingestPayload := IngestPayload{
		SensorID:  event.SensorID,
		Timestamp: event.Timestamp,
		Readings: []ParameterReading{
			{
				ParameterID: event.ParameterID,
				Value:       event.Value,
			},
		},
		Metadata: event.Metadata,
	}

	if _, err := c.handler.ProcessIngest(ingestPayload); err != nil {
		log.Printf("[ERROR] Failed to process ingest: %v", err)
		return err
	}

	return nil
}

func (c *AzureServiceBusConsumer) IsConnected() bool {
	return c.connected
}

func (c *AzureServiceBusConsumer) Ready() <-chan struct{} {
	return c.ready
}

func (c *AzureServiceBusConsumer) Close() error {
	closeCtx := context.Background()
	if c.receiver != nil {
		_ = c.receiver.Close(closeCtx)
	}
	if c.client != nil {
		return c.client.Close(closeCtx)
	}
	return nil
}

func getServiceBusConnection() string {
	return getEnv("SERVICE_BUS_CONNECTION", "")
}

func getServiceBusTopic() string {
	if topic := getEnv("SERVICE_BUS_TELEMETRY_TOPIC", ""); topic != "" {
		return topic
	}
	return getEnv("SERVICE_BUS_TOPIC", "telemetry")
}

func getServiceBusSubscription() string {
	if sub := getEnv("SERVICE_BUS_ANALYTICS_SUBSCRIPTION", ""); sub != "" {
		return sub
	}
	if sub := getEnv("SERVICE_BUS_TELEMETRY_SUBSCRIPTION", ""); sub != "" {
		return sub
	}
	return getEnv("SERVICE_BUS_SUBSCRIPTION", "analytics-service")
}

func getServiceBusNotificationTopic() string {
	if topic := getEnv("SERVICE_BUS_NOTIFICATIONS_TOPIC", ""); topic != "" {
		return topic
	}
	if topic := getEnv("SERVICE_BUS_NOTIFICATION_TOPIC", ""); topic != "" {
		return topic
	}
	return "notifications"
}

func getServiceBusNotificationSubscription() string {
	if sub := getEnv("SERVICE_BUS_NOTIFICATION_SUBSCRIPTION", ""); sub != "" {
		return sub
	}
	return "notification-service"
}

func getServiceBusNotificationRecipient() string {
	if recipient := getEnv("ALERT_NOTIFICATION_RECIPIENT", ""); recipient != "" {
		return recipient
	}
	if recipient := getEnv("SERVICE_BUS_NOTIFICATION_RECIPIENT", ""); recipient != "" {
		return recipient
	}
	return "alerts@agriwizard.local"
}

func stringPtr(s string) *string {
	return &s
}
