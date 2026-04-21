package main

import (
	"context"
	"encoding/json"
	"log"
	"time"

	"github.com/nats-io/nats.go"
)

// Consumer listens on NATS JetStream for notification requests.
type Consumer struct {
	nc  *nats.Conn
	js  nats.JetStreamContext
	sub *nats.Subscription
}

// StartConsumer connects to NATS, ensures the NOTIFICATIONS stream exists,
// and subscribes to "notifications.send" with a durable consumer.
func StartConsumer(natsURL string, dispatcher *Dispatcher) (*Consumer, error) {
	nc, err := nats.Connect(natsURL,
		nats.RetryOnFailedConnect(true),
		nats.MaxReconnects(-1),
		nats.ReconnectWait(2*time.Second),
		nats.DisconnectErrHandler(func(_ *nats.Conn, err error) {
			log.Printf("[WARN] NATS disconnected: %v", err)
		}),
		nats.ReconnectHandler(func(_ *nats.Conn) {
			log.Println("[INFO] NATS reconnected")
		}),
	)
	if err != nil {
		return nil, err
	}

	js, err := nc.JetStream()
	if err != nil {
		nc.Close()
		return nil, err
	}

	// Create or update stream (idempotent).
	_, err = js.AddStream(&nats.StreamConfig{
		Name:      "NOTIFICATIONS",
		Subjects:  []string{"notifications.>"},
		Retention: nats.LimitsPolicy,
		MaxAge:    72 * time.Hour,
		Storage:   nats.FileStorage,
	})
	if err != nil {
		nc.Close()
		return nil, err
	}
	log.Println("[INFO] NATS stream NOTIFICATIONS ready")

	// Durable push subscription with manual ack.
	sub, err := js.Subscribe("notifications.send", func(msg *nats.Msg) {
		var req NotificationRequest
		if err := json.Unmarshal(msg.Data, &req); err != nil {
			log.Printf("[ERROR] Unmarshal NATS message: %v", err)
			if termErr := msg.Term(); termErr != nil { // terminal failure — don't redeliver
				log.Printf("[ERROR] Failed to terminate NATS message: %v", termErr)
			}
			return
		}

		if err := dispatcher.Process(context.Background(), &req); err != nil {
			log.Printf("[ERROR] Process notification: %v", err)
			if nakErr := msg.Nak(); nakErr != nil { // redelivery
				log.Printf("[ERROR] Failed to NAK NATS message: %v", nakErr)
			}
			return
		}

		if ackErr := msg.Ack(); ackErr != nil {
			log.Printf("[ERROR] Failed to ACK NATS message: %v", ackErr)
		}
	},
		nats.Durable("notification-service"),
		nats.ManualAck(),
		nats.AckWait(30*time.Second),
		nats.MaxDeliver(3),
	)
	if err != nil {
		nc.Close()
		return nil, err
	}

	log.Println("[INFO] NATS consumer subscribed to notifications.send")
	return &Consumer{nc: nc, js: js, sub: sub}, nil
}

func (c *Consumer) Close() {
	if c.sub != nil {
		if err := c.sub.Unsubscribe(); err != nil {
			log.Printf("[WARN] Failed to unsubscribe NATS consumer: %v", err)
		}
	}
	if c.nc != nil {
		if err := c.nc.Drain(); err != nil {
			log.Printf("[WARN] Failed to drain NATS connection: %v", err)
		}
	}
}
