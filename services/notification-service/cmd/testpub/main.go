// testpub is a CLI tool that publishes test notifications to NATS JetStream.
//
// Usage:
//
//	go run ./cmd/testpub                           # send a raw email
//	go run ./cmd/testpub -template my-template-id  # send using a template
//	go run ./cmd/testpub -nats nats://host:4222    # custom NATS URL
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"time"

	"github.com/nats-io/nats.go"
)

func main() {
	natsURL := flag.String("nats", "nats://localhost:4222", "NATS server URL")
	recipient := flag.String("to", "test@example.com", "Recipient email address")
	templateID := flag.String("template", "", "Template ID (optional, uses raw mode if empty)")
	subject := flag.String("subject", "Test Notification", "Email subject (raw mode)")
	body := flag.String("body", "<h1>Hello!</h1><p>This is a test notification sent at "+time.Now().Format(time.RFC3339)+"</p>", "Email body (raw mode)")
	flag.Parse()

	nc, err := nats.Connect(*natsURL)
	if err != nil {
		log.Fatalf("NATS connect: %v", err)
	}
	defer nc.Close()

	js, err := nc.JetStream()
	if err != nil {
		log.Fatalf("JetStream: %v", err)
	}

	msg := map[string]any{
		"channel":   "email",
		"recipient": *recipient,
	}

	if *templateID != "" {
		msg["template_id"] = *templateID
		msg["variables"] = map[string]string{
			"name":  "Test User",
			"value": "42",
			"unit":  "%",
		}
		fmt.Printf("Sending template-based notification (template=%s) to %s\n", *templateID, *recipient)
	} else {
		msg["subject"] = *subject
		msg["body"] = *body
		fmt.Printf("Sending raw notification to %s\n", *recipient)
	}

	data, _ := json.MarshalIndent(msg, "", "  ")
	fmt.Printf("Payload:\n%s\n\n", data)

	dataFlat, _ := json.Marshal(msg)
	ack, err := js.Publish("notifications.send", dataFlat)
	if err != nil {
		log.Fatalf("Publish: %v", err)
	}

	fmt.Printf("Published to NOTIFICATIONS stream — seq=%d, stream=%s\n", ack.Sequence, ack.Stream)
}
