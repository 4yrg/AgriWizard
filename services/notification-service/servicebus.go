package main

import (
	"context"
	"encoding/json"
	"log"

	"github.com/Azure/azure-sdk-for-go/sdk/messaging/azservicebus"
)

type AzureServiceBusNotificationConsumer struct {
	client       *azservicebus.Client
	topicName    string
	subscription string
	dispatcher   *Dispatcher
	connected    bool
	ready        chan struct{}
	receiver     *azservicebus.Receiver
}

func NewAzureServiceBusNotificationConsumer(connectionString, topicName, subscription string, dispatcher *Dispatcher) (*AzureServiceBusNotificationConsumer, error) {
	if connectionString == "" {
		log.Println("[WARN] Azure Service Bus connection string not provided, running without Service Bus consumer")
		return &AzureServiceBusNotificationConsumer{connected: false, ready: make(chan struct{})}, nil
	}

	client, err := azservicebus.NewClientFromConnectionString(connectionString, nil)
	if err != nil {
		log.Printf("[WARN] Failed to create Service Bus client: %v", err)
		return &AzureServiceBusNotificationConsumer{connected: false, ready: make(chan struct{})}, nil
	}

	receiver, err := client.NewReceiverForSubscription(topicName, subscription, nil)
	if err != nil {
		log.Printf("[WARN] Failed to create Service Bus receiver: %v", err)
		client.Close(nil)
		return &AzureServiceBusNotificationConsumer{connected: false, ready: make(chan struct{})}, nil
	}

	log.Printf("[INFO] Azure Service Bus notification consumer ready, topic: %s, subscription: %s", topicName, subscription)

	return &AzureServiceBusNotificationConsumer{
		client:       client,
		topicName:    topicName,
		subscription: subscription,
		dispatcher:   dispatcher,
		connected:    true,
		ready:        make(chan struct{}),
		receiver:     receiver,
	}, nil
}

func (c *AzureServiceBusNotificationConsumer) Start(ctx context.Context) error {
	if !c.connected || c.receiver == nil {
		log.Println("[DEBUG] Azure Service Bus not connected, skipping consumer start")
		close(c.ready)
		return nil
	}

	close(c.ready)
	log.Printf("[INFO] Azure Service Bus notification consumer started, listening on topic=%s subscription=%s", c.topicName, c.subscription)

	for {
		select {
		case <-ctx.Done():
			log.Println("[INFO] Azure Service Bus notification consumer shutting down")
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

func (c *AzureServiceBusNotificationConsumer) processMessage(ctx context.Context, msg *azservicebus.ReceivedMessage) error {
	var req NotificationRequest
	if err := json.Unmarshal(msg.Body, &req); err != nil {
		log.Printf("[ERROR] Failed to unmarshal notification request: %v", err)
		return err
	}

	log.Printf("[DEBUG] Received notification request from Service Bus: channel=%s recipient=%s",
		req.Channel, req.Recipient)

	if err := c.dispatcher.Process(ctx, &req); err != nil {
		log.Printf("[ERROR] Failed to process notification: %v", err)
		return err
	}

	return nil
}

func (c *AzureServiceBusNotificationConsumer) IsConnected() bool {
	return c.connected
}

func (c *AzureServiceBusNotificationConsumer) Ready() <-chan struct{} {
	return c.ready
}

func (c *AzureServiceBusNotificationConsumer) Close() error {
	closeCtx := context.Background()
	if c.receiver != nil {
		_ = c.receiver.Close(closeCtx)
	}
	if c.client != nil {
		return c.client.Close(closeCtx)
	}
	return nil
}

func getServiceBusNotificationConnection() string {
	return getEnv("SERVICE_BUS_CONNECTION", "")
}

func getServiceBusNotificationTopic() string {
	return getEnv("SERVICE_BUS_TOPIC", "notifications")
}

func getServiceBusNotificationSubscription() string {
	return getEnv("SERVICE_BUS_SUBSCRIPTION", "notification-service")
}
