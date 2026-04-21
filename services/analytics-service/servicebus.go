package main

import (
	"context"
	"encoding/json"
	"log"

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

func NewAzureServiceBusConsumer(connectionString, topicName, subscription string, handler *Handler) (*AzureServiceBusConsumer, error) {
	if connectionString == "" {
		log.Println("[WARN] Azure Service Bus connection string not provided, running without Service Bus consumer")
		return &AzureServiceBusConsumer{connected: false, ready: make(chan struct{})}, nil
	}

	client, err := azservicebus.NewClientFromConnectionString(connectionString, nil)
	if err != nil {
		log.Printf("[WARN] Failed to create Service Bus client: %v", err)
		return &AzureServiceBusConsumer{connected: false, ready: make(chan struct{})}, nil
	}

	receiver, err := client.NewReceiverForSubscription(topicName, subscription, nil)
	if err != nil {
		log.Printf("[WARN] Failed to create Service Bus receiver: %v", err)
		client.Close(context.TODO())
		return &AzureServiceBusConsumer{connected: false, ready: make(chan struct{})}, nil
	}

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
			messages, err := c.receiver.ReceiveMessages(ctx, 1, nil)
			if err != nil {
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
	return getEnv("SERVICE_BUS_TOPIC", "telemetry")
}

func getServiceBusSubscription() string {
	return getEnv("SERVICE_BUS_SUBSCRIPTION", "analytics-service")
}
