package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
)

type RabbitMQPublisher struct {
	conn      *amqp.Connection
	channel   *amqp.Channel
	queue     string
	connected bool
}

type TelemetryEvent struct {
	SensorID    string                 `json:"sensor_id"`
	ParameterID string                 `json:"parameter_id"`
	Value       float64                `json:"value"`
	Timestamp   time.Time              `json:"timestamp"`
	Metadata    map[string]interface{} `json:"metadata,omitempty"`
}

func NewRabbitMQPublisher(url, queueName string) (*RabbitMQPublisher, error) {
	if url == "" {
		log.Println("[WARN] RabbitMQ URL not provided, running without RabbitMQ")
		return &RabbitMQPublisher{connected: false}, nil
	}

	conn, err := amqp.Dial(url)
	if err != nil {
		log.Printf("[WARN] Failed to connect to RabbitMQ: %v", err)
		return &RabbitMQPublisher{connected: false}, nil
	}

	ch, err := conn.Channel()
	if err != nil {
		log.Printf("[WARN] Failed to open RabbitMQ channel: %v", err)
		conn.Close()
		return &RabbitMQPublisher{connected: false}, nil
	}

	_, err = ch.QueueDeclare(
		queueName,
		true,  // durable
		false, // autoDelete
		false, // exclusive
		false, // noWait
		nil,
	)
	if err != nil {
		log.Printf("[ERROR] Failed to declare queue: %v", err)
		ch.Close()
		conn.Close()
		return &RabbitMQPublisher{connected: false}, nil
	}

	log.Printf("[INFO] RabbitMQ publisher connected, queue: %s", queueName)

	return &RabbitMQPublisher{
		conn:      conn,
		channel:   ch,
		queue:     queueName,
		connected: true,
	}, nil
}

func (r *RabbitMQPublisher) PublishTelemetry(ctx context.Context, event TelemetryEvent) error {
	if !r.connected || r.channel == nil {
		log.Println("[DEBUG] RabbitMQ not connected, skipping telemetry publish")
		return nil
	}

	body, err := json.Marshal(event)
	if err != nil {
		return err
	}

	err = r.channel.PublishWithContext(
		ctx,
		r.queue,
		"",
		false,
		false,
		amqp.Publishing{
			ContentType:  "application/json",
			Body:         body,
			DeliveryMode: amqp.Persistent,
			Timestamp:    time.Now(),
		},
	)
	if err != nil {
		log.Printf("[ERROR] RabbitMQ publish failed: %v", err)
		return err
	}

	log.Printf("[DEBUG] Published telemetry to RabbitMQ: sensor=%s value=%.2f queue=%s",
		event.SensorID, event.Value, r.queue)
	return nil
}

func (r *RabbitMQPublisher) IsConnected() bool {
	return r.connected
}

func (r *RabbitMQPublisher) Close() {
	if r.channel != nil {
		r.channel.Close()
	}
	if r.conn != nil {
		r.conn.Close()
	}
}

func getRabbitMQUrl() string {
	host := getEnv("RABBITMQ_HOST", "rabbitmq")
	port := getEnv("RABBITMQ_PORT", "5672")
	username := getEnv("RABBITMQ_USERNAME", "guest")
	password := getEnv("RABBITMQ_PASSWORD", "guest")

	return fmt.Sprintf("amqp://%s:%s@%s:%s", username, password, host, port)
}

func getQueueName() string {
	return getEnv("RABBITMQ_QUEUE", "telemetry")
}
