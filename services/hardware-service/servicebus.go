package main

import (
	"context"
	"encoding/json"
	"log"

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

	client, err := azservicebus.NewClientFromConnectionString(connectionString, nil)
	if err != nil {
		log.Printf("[WARN] Failed to create Service Bus client: %v", err)
		return &AzureServiceBusPublisher{connected: false}, nil
	}

	sender, err := client.NewSender(topicName, nil)
	if err != nil {
		log.Printf("[WARN] Failed to create Service Bus sender: %v", err)
		client.Close(nil)
		return &AzureServiceBusPublisher{connected: false}, nil
	}

	log.Printf("[INFO] Azure Service Bus publisher connected, topic: %s", topicName)

	return &AzureServiceBusPublisher{
		client:    client,
		topicName: topicName,
		sender:    sender,
		connected: true,
	}, nil
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
		p.sender.Close(nil)
	}
	if p.client != nil {
		return p.client.Close(nil)
	}
	return nil
}

func getServiceBusConnection() string {
	return getEnv("SERVICE_BUS_CONNECTION", "")
}

func getServiceBusTopic() string {
	return getEnv("SERVICE_BUS_TOPIC", "telemetry")
}

func stringPtr(s string) *string {
	return &s
}
