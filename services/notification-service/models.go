package main

import "time"

// --- Generic notification contract (zero coupling to any specific backend) ---

// NotificationRequest is the incoming payload via NATS or REST.
// Publishers only need to know this schema — nothing about the notification service internals.
// Channel can be "email", "in_app", or "all" (sends to both email and in-app).
type NotificationRequest struct {
	Channel    string            `json:"channel"`               // "email", "in_app", or "all"
	Recipient  string            `json:"recipient"`             // target address: email, user ID, etc.
	TemplateID string            `json:"template_id,omitempty"` // render a stored template instead of raw content
	Variables  map[string]string `json:"variables,omitempty"`   // template variables (e.g. {"name": "John"})
	Subject    string            `json:"subject,omitempty"`     // raw subject (ignored when template_id is set)
	Body       string            `json:"body,omitempty"`         // raw body (ignored when template_id is set)
	Metadata   map[string]string `json:"metadata,omitempty"`    // arbitrary key-value pairs passed through to the record
}

// Notification is the persisted record of a sent (or attempted) notification.
type Notification struct {
	ID        string            `json:"id"`
	Channel   string            `json:"channel"`
	Recipient string            `json:"recipient"`
	Subject   string            `json:"subject"`
	Body      string            `json:"body"`
	Status    string            `json:"status"` // "pending", "sent", "failed"
	Error     string            `json:"error,omitempty"`
	Metadata  map[string]string `json:"metadata,omitempty"`
	CreatedAt time.Time         `json:"created_at"`
	SentAt    *time.Time        `json:"sent_at,omitempty"`
	ReadAt    *time.Time        `json:"read_at,omitempty"`
}

// --- Templates ---

// Template is a reusable, channel-specific notification template.
// Subject and Body use Go text/template syntax: {{.variable_name}}
type Template struct {
	ID              string    `json:"id"`
	Name            string    `json:"name"`
	Channel         string    `json:"channel"`
	SubjectTemplate string    `json:"subject_template"`
	BodyTemplate    string    `json:"body_template"`
	CreatedAt       time.Time `json:"created_at"`
	UpdatedAt       time.Time `json:"updated_at"`
}

// CreateTemplateRequest is the REST payload for creating a template.
type CreateTemplateRequest struct {
	Name            string `json:"name"`
	Channel         string `json:"channel"`
	SubjectTemplate string `json:"subject_template"`
	BodyTemplate    string `json:"body_template"`
}

// UpdateTemplateRequest is the REST payload for updating a template.
type UpdateTemplateRequest struct {
	Name            string `json:"name,omitempty"`
	Channel         string `json:"channel,omitempty"`
	SubjectTemplate string `json:"subject_template,omitempty"`
	BodyTemplate    string `json:"body_template,omitempty"`
}

// --- API response helpers ---

type APIResponse struct {
	Message string `json:"message,omitempty"`
	Data    any    `json:"data,omitempty"`
	Error   string `json:"error,omitempty"`
}
