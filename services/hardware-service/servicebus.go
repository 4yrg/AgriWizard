package main

import (
	"context"
	"encoding/json"
	"log"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/messaging/azservicebus"
)

type ServiceBusPublisher struct {
	client     *azservicebus.Client
	topicName  string
	connected  bool
}

type TelemetryEvent struct {
	SensorID      string                 `json:"sensor_id"`
	ParameterID  string                 `json:"parameter_id"`
	Value        float64                `json:"value"`
	Timestamp    time.Time              `json:"timestamp"`
	Metadata     map[string]interface{} `json:"metadata,omitempty"`
}

func NewServiceBusPublisher(connectionString, topicName string) (*ServiceBusPublisher, error) {
	if connectionString == "" {
		log.Println("[WARN] Service Bus connection string not provided, running without SB")
		return &ServiceBusPublisher{connected: false}, nil
	}

	client, err := azservicebus.NewClientFromConnectionString(connectionString, nil)
	if err != nil {
		log.Printf("[WARN] Failed to create Service Bus client: %v", err)
		return &ServiceBusPublisher{connected: false}, nil
	}

	return &ServiceBusPublisher{
		client:    client,
		topicName: topicName,
		connected: true,
	}, nil
}

func (s *ServiceBusPublisher) PublishTelemetry(ctx context.Context, event TelemetryEvent) error {
	if !s.connected || s.client == nil {
		log.Println("[DEBUG] Service Bus not connected, skipping telemetry publish")
		return nil
	}

	sender, err := s.client.NewSender(s.topicName, nil)
	if err != nil {
		log.Printf("[ERROR] Service Bus sender creation failed: %v", err)
		return err
	}
	defer sender.Close(ctx)

	body, err := json.Marshal(event)
	if err != nil {
		return err
	}

	msg := &azservicebus.Message{
		Body: body,
		ContentType: func() *string {
		 ct := "application/json"
		 return &ct
		}(),
	}

	err = sender.SendMessage(ctx, msg, nil)
	if err != nil {
		log.Printf("[ERROR] Service Bus send failed: %v", err)
		return err
	}

	log.Printf("[DEBUG] Published telemetry to Service Bus: sensor=%s value=%.2f", event.SensorID, event.Value)
	return nil
}

func (s *ServiceBusPublisher) IsConnected() bool {
	return s.connected
}
