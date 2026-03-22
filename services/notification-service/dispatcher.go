package main

import (
	"context"
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
func (d *Dispatcher) Process(ctx context.Context, req *NotificationRequest) error {
	// 1. Validate
	if req.Channel == "" {
		return fmt.Errorf("channel is required")
	}
	if req.Recipient == "" {
		return fmt.Errorf("recipient is required")
	}

	// 2. Resolve content — template takes precedence over raw fields
	subject, body := req.Subject, req.Body
	if req.TemplateID != "" {
		var err error
		subject, body, err = d.engine.Render(req.TemplateID, req.Variables)
		if err != nil {
			return fmt.Errorf("template render: %w", err)
		}
	}

	// 3. Create persisted record
	n := &Notification{
		ID:        uuid.New().String(),
		Channel:   req.Channel,
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

	// 4. Route to channel sender
	sender, ok := d.channels[req.Channel]
	if !ok {
		errMsg := fmt.Sprintf("unknown channel: %s", req.Channel)
		d.store.UpdateStatus(n.ID, "failed", errMsg, nil)
		return fmt.Errorf(errMsg)
	}

	// 5. Deliver
	if err := sender.Send(ctx, n); err != nil {
		d.store.UpdateStatus(n.ID, "failed", err.Error(), nil)
		return fmt.Errorf("send via %s: %w", req.Channel, err)
	}

	// 6. Mark as sent
	now := time.Now().UTC()
	d.store.UpdateStatus(n.ID, "sent", "", &now)
	log.Printf("[INFO] Notification %s sent via %s to %s", n.ID, n.Channel, n.Recipient)
	return nil
}
