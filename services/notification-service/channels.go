package main

import (
	"context"
	"crypto/tls"
	"fmt"
	"log"
	"net"
	"net/smtp"
)

// Sender is the interface every notification channel must implement.
// To add a new channel (SMS, webhook, push, etc.), implement this interface
// and register the sender in main.go — no other code changes required.
type Sender interface {
	// Type returns the channel identifier (e.g. "email", "sms", "webhook").
	Type() string
	// Send delivers the notification. The Notification record already has
	// the rendered Subject and Body by the time Send is called.
	Send(ctx context.Context, n *Notification) error
}

// --- Email channel ---

type EmailSender struct {
	Host     string
	Port     string
	From     string
	Username string
	Password string
}

func (e *EmailSender) Type() string { return "email" }

func (e *EmailSender) Send(ctx context.Context, n *Notification) error {
	addr := net.JoinHostPort(e.Host, e.Port)

	c, err := smtp.Dial(addr)
	if err != nil {
		return fmt.Errorf("smtp dial %s: %w", addr, err)
	}
	defer c.Close()

	// Upgrade to TLS if the server supports STARTTLS.
	if ok, _ := c.Extension("STARTTLS"); ok {
		if err := c.StartTLS(&tls.Config{ServerName: e.Host}); err != nil {
			return fmt.Errorf("starttls: %w", err)
		}
	}

	// Authenticate only when credentials are provided.
	if e.Username != "" {
		auth := smtp.PlainAuth("", e.Username, e.Password, e.Host)
		if err := c.Auth(auth); err != nil {
			return fmt.Errorf("smtp auth: %w", err)
		}
	}

	if err := c.Mail(e.From); err != nil {
		return fmt.Errorf("mail from: %w", err)
	}
	if err := c.Rcpt(n.Recipient); err != nil {
		return fmt.Errorf("rcpt to: %w", err)
	}

	w, err := c.Data()
	if err != nil {
		return fmt.Errorf("data: %w", err)
	}

	msg := fmt.Sprintf(
		"From: %s\r\nTo: %s\r\nSubject: %s\r\nMIME-Version: 1.0\r\nContent-Type: text/html; charset=UTF-8\r\n\r\n%s",
		e.From, n.Recipient, n.Subject, n.Body,
	)

	if _, err := w.Write([]byte(msg)); err != nil {
		return fmt.Errorf("write body: %w", err)
	}
	if err := w.Close(); err != nil {
		return fmt.Errorf("close data: %w", err)
	}

	return c.Quit()
}

// --- In-App channel ---

type InAppSender struct{}

func (s *InAppSender) Type() string { return "in_app" }

func (s *InAppSender) Send(ctx context.Context, n *Notification) error {
	log.Printf("[INFO] In-app notification stored: id=%s recipient=%s subject=%s", n.ID, n.Recipient, n.Subject)
	return nil
}
