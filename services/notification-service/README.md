# Notification Service

A standalone, pluggable notification service powered by **NATS JetStream**.
Zero coupling — plug it into any backend.

---

## Quick Start

```bash
cd services/notification-service
docker compose up --build
```

This starts 4 containers:

| Service              | URL                        | Purpose                  |
|----------------------|----------------------------|--------------------------|
| Notification Service | http://localhost:8085       | REST API                 |
| NATS JetStream       | nats://localhost:4222       | Message queue            |
| MailHog              | http://localhost:8025       | Fake email inbox (Web UI)|
| PostgreSQL           | localhost:5433              | Notification storage     |

---

## Two Ways to Send Notifications

### 1. REST API (no NATS needed)

Send a notification directly via HTTP:

```bash
curl -X POST http://localhost:8085/api/v1/notifications/send \
  -H "Content-Type: application/json" \
  -d '{
    "channel": "email",
    "recipient": "farmer@example.com",
    "subject": "Hello",
    "body": "<p>Your crops are growing well!</p>"
  }'
```

### 2. NATS JetStream (async, decoupled)

Any service publishes a message to NATS — the notification service picks it up:

```bash
go run ./cmd/testpub -to farmer@example.com
```

Or from any NATS client, publish to subject `notifications.send`:

```json
{
  "channel": "email",
  "recipient": "farmer@example.com",
  "subject": "Hello",
  "body": "<p>Your crops are growing well!</p>"
}
```

> **After sending**, open http://localhost:8025 to see the email in MailHog.

---

## Templates (This is just optional)

Templates let you reuse notification layouts. The only "coupling" point —
swap templates when you plug this service into a different backend.

### Step 1: Create a template

```bash
curl -X POST http://localhost:8085/api/v1/templates \
  -H "Content-Type: application/json" \
  -d '{
    "name": "threshold_alert",
    "channel": "email",
    "subject_template": "⚠ Alert: {{.param}} out of range",
    "body_template": "<h2>{{.param}}</h2><p>Current value: <b>{{.value}}{{.unit}}</b></p><p>Please check your greenhouse.</p>"
  }'
```

Response:

```json
{
  "message": "template created",
  "data": {
    "id": "a1b2c3d4-...",
    "name": "threshold_alert",
    ...
  }
}
```

> Save the `id` — you'll use it when sending.

### Step 2: Send using the template

```bash
curl -X POST http://localhost:8085/api/v1/notifications/send \
  -H "Content-Type: application/json" \
  -d '{
    "channel": "email",
    "recipient": "farmer@example.com",
    "template_id": "a1b2c3d4-...",
    "variables": {
      "param": "Soil Moisture",
      "value": "12",
      "unit": "%"
    }
  }'
```

The service renders `{{.param}}` → `Soil Moisture`, `{{.value}}` → `12`, etc.

### Template vs Raw — when to use which?

| Mode     | When to use                          | Fields needed                    |
|----------|--------------------------------------|----------------------------------|
| Raw      | One-off or dynamic messages          | `subject` + `body`               |
| Template | Repeatable alerts, reports, digests  | `template_id` + `variables`      |

> If `template_id` is provided, `subject` and `body` are ignored.

---

## Notification History

### List all notifications

```bash
curl http://localhost:8085/api/v1/notifications?limit=10&offset=0
```

### Get a single notification

```bash
curl http://localhost:8085/api/v1/notifications/{id}
```

Each record includes: `status` (`pending`, `sent`, `failed`), timestamps, and any error message.

---

## Template Management

| Method   | Endpoint                      | Description         |
|----------|-------------------------------|---------------------|
| `POST`   | `/api/v1/templates`           | Create template     |
| `GET`    | `/api/v1/templates`           | List all templates  |
| `GET`    | `/api/v1/templates/{id}`      | Get template        |
| `PUT`    | `/api/v1/templates/{id}`      | Update template     |
| `DELETE` | `/api/v1/templates/{id}`      | Delete template     |

---

## Message Contract

This is the only schema any publisher needs to know:

```json
{
  "channel": "email",
  "recipient": "user@example.com",

  "template_id": "optional-template-id",
  "variables": { "key": "value" },

  "subject": "used when no template_id",
  "body": "used when no template_id",

  "metadata": { "source": "analytics-service" }
}
```

- `channel` + `recipient` — always required
- Provide either `template_id` + `variables` **or** `subject` + `body`
- `metadata` — optional key-value pairs, stored with the notification record

---

## Adding New Channels (SMS, Webhook, Push, etc.)

Implement the `Sender` interface in a new file:

```go
type Sender interface {
    Type() string
    Send(ctx context.Context, n *Notification) error
}
```

Then register it in `main.go`:

```go
dispatcher.RegisterChannel(&SMSSender{...})
```

No other code changes needed.

---

## Architecture

```
┌──────────────┐    publish     ┌──────────────┐
│  Any Service │ ──────────────▶│     NATS     │
│  (producer)  │  notifications │  JetStream   │
└──────────────┘    .send       └──────┬───────┘
                                       │ consume
                                       ▼
                    ┌──────────────────────────────────┐
  POST /send ──────▶│      Notification Service        │
                    │                                  │
                    │  1. Resolve template (if any)     │
                    │  2. Save to PostgreSQL            │
                    │  3. Route to channel (email/...)  │
                    │  4. Update delivery status        │
                    └───────────┬──────────────────────┘
                                │
                    ┌───────────▼───────────┐
                    │   Channel Senders     │
                    │  ┌───────┐ ┌───────┐  │
                    │  │ Email │ │  SMS  │  │
                    │  └───────┘ └───────┘  │
                    │  ┌─────────┐ ┌──────┐ │
                    │  │ Webhook │ │ Push │  │
                    │  └─────────┘ └──────┘ │
                    └───────────────────────┘
```

---

## Environment Variables

| Variable        | Default                      | Description              |
|-----------------|------------------------------|--------------------------|
| `PORT`          | `8085`                       | HTTP server port         |
| `DB_HOST`       | `localhost`                  | PostgreSQL host          |
| `DB_PORT`       | `5432`                       | PostgreSQL port          |
| `DB_USER`       | `notification`               | PostgreSQL user          |
| `DB_PASSWORD`   | `notification_secret`        | PostgreSQL password      |
| `DB_NAME`       | `notification`               | PostgreSQL database      |
| `NATS_URL`      | `nats://localhost:4222`      | NATS server URL          |
| `SMTP_HOST`     | `localhost`                  | SMTP server host         |
| `SMTP_PORT`     | `1025`                       | SMTP server port         |
| `SMTP_FROM`     | `noreply@notification.local` | Sender email address     |
| `SMTP_USERNAME` | *(empty)*                    | SMTP auth username       |
| `SMTP_PASSWORD` | *(empty)*                    | SMTP auth password       |

> NATS is optional — if unavailable, the REST API still works.
