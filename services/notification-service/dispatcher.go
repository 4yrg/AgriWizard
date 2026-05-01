package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"time"

	"github.com/google/uuid"
)

// Dispatcher orchestrates notification processing:
//  1. Resolve template (if template_id provided)
//  2. Persist the notification record
//  3. Route to the appropriate channel sender
//  4. Update delivery status
//
// To add a new channel, register it via RegisterChannel — no other changes needed.
type Dispatcher struct {
	store    *Store
	engine   *TemplateEngine
	channels map[string]Sender
}

func NewDispatcher(store *Store, engine *TemplateEngine) *Dispatcher {
	return &Dispatcher{
		store:    store,
		engine:   engine,
		channels: make(map[string]Sender),
	}
}

// RegisterChannel registers a delivery channel (e.g. email, sms, webhook).
func (d *Dispatcher) RegisterChannel(s Sender) {
	d.channels[s.Type()] = s
	log.Printf("[INFO] Channel registered: %s", s.Type())
}

// Process handles a single notification request end-to-end.
// When channel is "all", it dispatches to both "email" and "in_app" channels.
func (d *Dispatcher) Process(ctx context.Context, req *NotificationRequest) error {
	// 1. Validate
	if req.Channel == "" {
		return fmt.Errorf("channel is required")
	}
	if req.Recipient == "" {
		return fmt.Errorf("recipient is required")
	}

	// 2. Expand "all" into separate channels
	channels := []string{req.Channel}
	if req.Channel == "all" {
		channels = []string{"email", "in_app"}
	}

	var firstErr error
	for _, ch := range channels {
		if err := d.processSingle(ctx, req, ch); err != nil && firstErr == nil {
			firstErr = err
		}
	}
	return firstErr
}

func (d *Dispatcher) processSingle(ctx context.Context, req *NotificationRequest, channel string) error {
	// Resolve content — template takes precedence over raw fields
	subject, body := req.Subject, req.Body
	if req.TemplateID != "" {
		var err error
		subject, body, err = d.engine.Render(req.TemplateID, req.Variables)
		if err != nil {
			return fmt.Errorf("template render: %w", err)
		}
	}

	// Create persisted record
	n := &Notification{
		ID:        uuid.New().String(),
		Channel:   channel,
		Recipient: req.Recipient,
		Subject:   subject,
		Body:      body,
		Status:    "pending",
		Metadata:  req.Metadata,
		CreatedAt: time.Now().UTC(),
	}
	if err := d.store.SaveNotification(n); err != nil {
		return fmt.Errorf("save notification: %w", err)
	}

	// Route to channel sender
	sender, ok := d.channels[channel]
	if !ok {
		errMsg := fmt.Sprintf("unknown channel: %s", channel)
		if statusErr := d.store.UpdateStatus(n.ID, "failed", errMsg, nil); statusErr != nil {
			log.Printf("[ERROR] Failed to update notification status to failed: %v", statusErr)
		}
		return errors.New(errMsg)
	}

	// Deliver
	if err := sender.Send(ctx, n); err != nil {
		if statusErr := d.store.UpdateStatus(n.ID, "failed", err.Error(), nil); statusErr != nil {
			log.Printf("[ERROR] Failed to update notification status to failed: %v", statusErr)
		}
		return fmt.Errorf("send via %s: %w", channel, err)
	}

	// Mark as sent
	now := time.Now().UTC()
	if statusErr := d.store.UpdateStatus(n.ID, "sent", "", &now); statusErr != nil {
		log.Printf("[ERROR] Failed to update notification status to sent: %v", statusErr)
	}
	log.Printf("[INFO] Notification %s sent via %s to %s", n.ID, n.Channel, n.Recipient)
	return nil
}
