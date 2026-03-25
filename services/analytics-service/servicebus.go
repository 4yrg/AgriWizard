package main

import (
	"context"
	"encoding/json"
	"log"
	"os"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/messaging/azservicebus"
)

type TelemetryEvent struct {
	SensorID     string                 `json:"sensor_id"`
	ParameterID  string                 `json:"parameter_id"`
	Value       float64                `json:"value"`
	Timestamp   time.Time              `json:"timestamp"`
	Metadata    map[string]interface{} `json:"metadata,omitempty"`
}

type ServiceBusConsumer struct {
	client       *azservicebus.Client
	topicName    string
	subscription string
	handler      *Handler
	connected    bool
	ready        chan struct{}
}

func NewServiceBusConsumer(connectionString, namespace, topicName, subscription string, handler *Handler) (*ServiceBusConsumer, error) {
	if connectionString == "" {
		log.Println("[WARN] Service Bus connection string not provided, running without SB consumer")
		return &ServiceBusConsumer{connected: false, ready: make(chan struct{})}, nil
	}

	client, err := azservicebus.NewClientFromConnectionString(connectionString, nil)
	if err != nil {
		log.Printf("[WARN] Failed to create Service Bus client: %v", err)
		return &ServiceBusConsumer{connected: false, ready: make(chan struct{})}, nil
	}

	return &ServiceBusConsumer{
		client:       client,
		topicName:    topicName,
		subscription: subscription,
		handler:      handler,
		connected:    true,
		ready:        make(chan struct{}),
	}, nil
}

func (s *ServiceBusConsumer) Start(ctx context.Context) error {
	if !s.connected || s.client == nil {
		log.Println("[DEBUG] Service Bus not connected, skipping consumer start")
		close(s.ready)
		return nil
	}

	receiver, err := s.client.NewReceiver(s.topicName, s.subscription, nil)
	if err != nil {
		log.Printf("[ERROR] Service Bus receiver creation failed: %v", err)
		close(s.ready)
		return err
	}
	defer receiver.Close(ctx)

	close(s.ready)
	log.Printf("[INFO] Service Bus consumer started, listening on topic=%s subscription=%s", s.topicName, s.subscription)

	for {
		select {
		case <-ctx.Done():
			log.Println("[INFO] Service Bus consumer shutting down")
			return nil
		default:
		}

		messages, err := receiver.ReceiveMessages(ctx, 1, nil)
		if err != nil {
			if ctx.Err() != nil {
				return nil
			}
			log.Printf("[ERROR] Service Bus receive failed: %v", err)
			time.Sleep(2 * time.Second)
			continue
		}

		for _, msg := range messages {
			if err := s.processMessage(ctx, msg); err != nil {
				log.Printf("[ERROR] Failed to process message: %v", err)
				_, dlqErr := receiver.DeadLetterMessage(ctx, msg, nil)
				if dlqErr != nil {
					log.Printf("[ERROR] Failed to dead letter message: %v", dlqErr)
				}
			} else {
				err = receiver.CompleteMessage(ctx, msg, nil)
				if err != nil {
					log.Printf("[ERROR] Failed to complete message: %v", err)
				}
			}
		}
	}
}

func (s *ServiceBusConsumer) processMessage(ctx context.Context, msg *azservicebus.ReceivedMessage) error {
	var event TelemetryEvent
	if err := json.Unmarshal(msg.Body, &event); err != nil {
		log.Printf("[ERROR] Failed to unmarshal telemetry event: %v", err)
		return err
	}

	log.Printf("[DEBUG] Received telemetry from Service Bus: sensor=%s param=%s value=%.2f",
		event.SensorID, event.ParameterID, event.Value)

	ingestPayload := IngestPayload{
		SensorID:   event.SensorID,
		Timestamp:  event.Timestamp,
		Readings: []ParameterReading{
			{
				ParameterID: event.ParameterID,
				Value:       event.Value,
			},
		},
		Metadata: event.Metadata,
	}

	if err := s.handler.ProcessIngest(ingestPayload); err != nil {
		log.Printf("[ERROR] Failed to process ingest: %v", err)
		return err
	}

	return nil
}

func (s *ServiceBusConsumer) IsConnected() bool {
	return s.connected
}

func (s *ServiceBusConsumer) Ready() <-chan struct{} {
	return s.ready
}
