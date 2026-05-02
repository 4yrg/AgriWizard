package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/messaging/azservicebus"
)

type AzureServiceBusPublisher struct {
	client    *azservicebus.Client
	topicName string
	connected bool
	sender    *azservicebus.Sender
}

func NewAzureServiceBusPublisher(connectionString, topicName string) (*AzureServiceBusPublisher, error) {
	if connectionString == "" {
		log.Println("[WARN] Azure Service Bus connection string not provided, running without Service Bus")
		return &AzureServiceBusPublisher{connected: false}, nil
	}

	var client *azservicebus.Client
	var err error
	for i := 0; i < 10; i++ {
		client, err = azservicebus.NewClientFromConnectionString(connectionString, nil)
		if err == nil {
			sender, err := client.NewSender(topicName, nil)
			if err == nil {
				log.Printf("[INFO] Azure Service Bus publisher connected, topic: %s", topicName)
				return &AzureServiceBusPublisher{
					client:    client,
					topicName: topicName,
					sender:    sender,
					connected: true,
				}, nil
			}
			log.Printf("[WARN] Failed to create Service Bus sender (attempt %d/10): %v", i+1, err)
			client.Close(context.TODO())
		} else {
			log.Printf("[WARN] Failed to create Service Bus client (attempt %d/10): %v", i+1, err)
		}
		time.Sleep(5 * time.Second)
	}

	return &AzureServiceBusPublisher{connected: false}, fmt.Errorf("failed to connect to Azure Service Bus after 10 attempts: %v", err)
}

func (p *AzureServiceBusPublisher) PublishTelemetry(ctx context.Context, event TelemetryEvent) error {
	if !p.connected || p.sender == nil {
		log.Println("[DEBUG] Azure Service Bus not connected, skipping telemetry publish")
		return nil
	}

	body, err := json.Marshal(event)
	if err != nil {
		return err
	}

	message := &azservicebus.Message{
		Body:        body,
		ContentType: stringPtr("application/json"),
	}

	err = p.sender.SendMessage(ctx, message, nil)
	if err != nil {
		log.Printf("[ERROR] Azure Service Bus publish failed: %v", err)
		return err
	}

	log.Printf("[DEBUG] Published telemetry to Service Bus: sensor=%s value=%.2f topic=%s",
		event.SensorID, event.Value, p.topicName)
	return nil
}

func (p *AzureServiceBusPublisher) IsConnected() bool {
	return p.connected
}

func (p *AzureServiceBusPublisher) Close() error {
	if p.sender != nil {
		p.sender.Close(context.TODO())
	}
	if p.client != nil {
		return p.client.Close(context.TODO())
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

// AzureServiceBusNotificationPublisher sends notifications to Service Bus
type AzureServiceBusNotificationPublisher struct {
	client    *azservicebus.Client
	topicName string
	connected bool
	sender    *azservicebus.Sender
}

// NotificationRequest matches the schema expected by the notification-service
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

	log.Printf("[DEBUG] Published notification to Service Bus: recipient=%s topic=%s", req.Recipient, p.topicName)
	return nil
}

func (p *AzureServiceBusNotificationPublisher) IsConnected() bool {
	return p.connected
}

func (p *AzureServiceBusNotificationPublisher) CloseNotification() error {
	if p.sender != nil {
		p.sender.Close(context.TODO())
	}
	if p.client != nil {
		return p.client.Close(context.TODO())
	}
	return nil
}

func getServiceBusNotificationsTopic() string {
	if topic := getEnv("SERVICE_BUS_NOTIFICATIONS_TOPIC", ""); topic != "" {
		return topic
	}
	if topic := getEnv("SERVICE_BUS_NOTIFICATION_TOPIC", ""); topic != "" {
		return topic
	}
	return "notifications"
}

func getServiceBusNotificationRecipient() string {
	if recipient := getEnv("ALERT_NOTIFICATION_RECIPIENT", ""); recipient != "" {
		return recipient
	}
	if recipient := getEnv("SERVICE_BUS_NOTIFICATION_RECIPIENT", ""); recipient != "" {
		return recipient
	}
	return "admin@agriwizard.local"
}

func stringPtr(s string) *string {
	return &s
}
