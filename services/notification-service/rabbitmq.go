package main

import (
	"context"
	"encoding/json"
	"log"

	amqp "github.com/rabbitmq/amqp091-go"
)

type NotificationEvent struct {
	Type      string            `json:"type"`
	Recipient string            `json:"recipient"`
	Subject   string            `json:"subject"`
	Body      string            `json:"body"`
	Data      map[string]string `json:"data,omitempty"`
	Metadata  map[string]string `json:"metadata,omitempty"`
}

type RabbitMQConsumer struct {
	conn       *amqp.Connection
	channel    *amqp.Channel
	queue      string
	dispatcher *Dispatcher
	connected  bool
	ready      chan struct{}
}

func NewRabbitMQConsumer(url, queueName string, dispatcher *Dispatcher) (*RabbitMQConsumer, error) {
	if url == "" {
		log.Println("[WARN] RabbitMQ URL not provided, running without RabbitMQ consumer")
		return &RabbitMQConsumer{connected: false, ready: make(chan struct{})}, nil
	}

	conn, err := amqp.Dial(url)
	if err != nil {
		log.Printf("[WARN] Failed to connect to RabbitMQ: %v", err)
		return &RabbitMQConsumer{connected: false, ready: make(chan struct{})}, nil
	}

	ch, err := conn.Channel()
	if err != nil {
		log.Printf("[WARN] Failed to open RabbitMQ channel: %v", err)
		conn.Close()
		return &RabbitMQConsumer{connected: false, ready: make(chan struct{})}, nil
	}

	_, err = ch.QueueDeclare(
		queueName,
		true,
		false,
		false,
		false,
		nil,
	)
	if err != nil {
		log.Printf("[ERROR] Failed to declare queue: %v", err)
		ch.Close()
		conn.Close()
		return &RabbitMQConsumer{connected: false, ready: make(chan struct{})}, nil
	}

	err = ch.Qos(1, 0, false)
	if err != nil {
		log.Printf("[WARN] Failed to set QoS: %v", err)
	}

	log.Printf("[INFO] RabbitMQ consumer ready, queue: %s", queueName)

	return &RabbitMQConsumer{
		conn:       conn,
		channel:    ch,
		queue:      queueName,
		dispatcher: dispatcher,
		connected:  true,
		ready:      make(chan struct{}),
	}, nil
}

func (r *RabbitMQConsumer) Start(ctx context.Context) error {
	if !r.connected || r.channel == nil {
		log.Println("[DEBUG] RabbitMQ not connected, skipping consumer start")
		close(r.ready)
		return nil
	}

	msgs, err := r.channel.Consume(
		r.queue,
		"",
		false,
		false,
		false,
		false,
		nil,
	)
	if err != nil {
		log.Printf("[ERROR] Failed to register consumer: %v", err)
		close(r.ready)
		return err
	}

	close(r.ready)
	log.Printf("[INFO] RabbitMQ consumer started, listening on queue=%s", r.queue)

	for {
		select {
		case <-ctx.Done():
			log.Println("[INFO] RabbitMQ consumer shutting down")
			return nil
		case msg, ok := <-msgs:
			if !ok {
				log.Println("[WARN] RabbitMQ channel closed")
				return nil
			}
			if err := r.processMessage(ctx, msg); err != nil {
				log.Printf("[ERROR] Failed to process message: %v", err)
				msg.Nack(false, true)
			} else {
				msg.Ack(false)
			}
		}
	}
}

func (r *RabbitMQConsumer) processMessage(ctx context.Context, msg amqp.Delivery) error {
	var event NotificationEvent
	if err := json.Unmarshal(msg.Body, &event); err != nil {
		log.Printf("[ERROR] Failed to unmarshal notification event: %v", err)
		return err
	}

	log.Printf("[DEBUG] Received notification from RabbitMQ: type=%s recipient=%s",
		event.Type, event.Recipient)

	// Process notification through dispatcher
	req := &NotificationRequest{
		Channel:   event.Type,
		Recipient: event.Recipient,
		Subject:   event.Subject,
		Body:      event.Body,
		Variables: event.Data,
		Metadata:  event.Metadata,
	}
	err := r.dispatcher.Process(context.Background(), req)
	if err != nil {
		log.Printf("[ERROR] Failed to send notification: %v", err)
		return err
	}

	return nil
}

func (r *RabbitMQConsumer) IsConnected() bool {
	return r.connected
}

func (r *RabbitMQConsumer) Ready() <-chan struct{} {
	return r.ready
}

func getRabbitMQUrl() string {
	host := getEnv("RABBITMQ_HOST", "rabbitmq")
	port := getEnv("RABBITMQ_PORT", "5672")
	username := getEnv("RABBITMQ_USERNAME", "guest")
	password := getEnv("RABBITMQ_PASSWORD", "guest")

	return "amqp://" + username + ":" + password + "@" + host + ":" + port
}

func getQueueName() string {
	return getEnv("RABBITMQ_QUEUE", "notifications")
}
