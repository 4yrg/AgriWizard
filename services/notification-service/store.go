package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"time"

	_ "github.com/lib/pq"
)

type Store struct {
	db *sql.DB
}

func NewStore(db *sql.DB) *Store {
	return &Store{db: db}
}

// ---- Notifications ----

func (s *Store) SaveNotification(n *Notification) error {
	metaJSON, _ := json.Marshal(n.Metadata)
	_, err := s.db.Exec(`
		INSERT INTO notifications.notifications
			(id, channel, recipient, subject, body, status, error_msg, metadata, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb, $9)`,
		n.ID, n.Channel, n.Recipient, n.Subject, n.Body, n.Status, n.Error, metaJSON, n.CreatedAt)
	return err
}

func (s *Store) UpdateStatus(id, status, errMsg string, sentAt *time.Time) error {
	_, err := s.db.Exec(`
		UPDATE notifications.notifications
		SET status = $1, error_msg = $2, sent_at = $3
		WHERE id = $4`,
		status, errMsg, sentAt, id)
	return err
}

func (s *Store) GetNotification(id string) (*Notification, error) {
	n := &Notification{}
	var metaJSON []byte
	var errMsg sql.NullString
	var sentAt sql.NullTime

	err := s.db.QueryRow(`
		SELECT id, channel, recipient, subject, body, status, error_msg, metadata, created_at, sent_at
		FROM notifications.notifications WHERE id = $1`, id).
		Scan(&n.ID, &n.Channel, &n.Recipient, &n.Subject, &n.Body, &n.Status,
			&errMsg, &metaJSON, &n.CreatedAt, &sentAt)
	if err != nil {
		return nil, err
	}
	if errMsg.Valid {
		n.Error = errMsg.String
	}
	if sentAt.Valid {
		n.SentAt = &sentAt.Time
	}
	if metaJSON != nil {
		if err := json.Unmarshal(metaJSON, &n.Metadata); err != nil {
			return nil, fmt.Errorf("decode notification metadata for %s: %w", n.ID, err)
		}
	}
	return n, nil
}

func (s *Store) ListNotifications(limit, offset int) ([]Notification, error) {
	rows, err := s.db.Query(`
		SELECT id, channel, recipient, subject, body, status, error_msg, metadata, created_at, sent_at
		FROM notifications.notifications
		ORDER BY created_at DESC
		LIMIT $1 OFFSET $2`, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []Notification
	for rows.Next() {
		var n Notification
		var metaJSON []byte
		var errMsg sql.NullString
		var sentAt sql.NullTime

		if err := rows.Scan(&n.ID, &n.Channel, &n.Recipient, &n.Subject, &n.Body, &n.Status,
			&errMsg, &metaJSON, &n.CreatedAt, &sentAt); err != nil {
			return nil, err
		}
		if errMsg.Valid {
			n.Error = errMsg.String
		}
		if sentAt.Valid {
			n.SentAt = &sentAt.Time
		}
		if metaJSON != nil {
			if err := json.Unmarshal(metaJSON, &n.Metadata); err != nil {
				return nil, fmt.Errorf("decode notification metadata for %s: %w", n.ID, err)
			}
		}
		list = append(list, n)
	}
	return list, nil
}

// ---- Templates ----

func (s *Store) CreateTemplate(t *Template) error {
	_, err := s.db.Exec(`
		INSERT INTO notifications.templates
			(id, name, channel, subject_template, body_template, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)`,
		t.ID, t.Name, t.Channel, t.SubjectTemplate, t.BodyTemplate, t.CreatedAt, t.UpdatedAt)
	return err
}

func (s *Store) GetTemplate(id string) (*Template, error) {
	t := &Template{}
	err := s.db.QueryRow(`
		SELECT id, name, channel, subject_template, body_template, created_at, updated_at
		FROM notifications.templates WHERE id = $1`, id).
		Scan(&t.ID, &t.Name, &t.Channel, &t.SubjectTemplate, &t.BodyTemplate, &t.CreatedAt, &t.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return t, nil
}

func (s *Store) ListTemplates() ([]Template, error) {
	rows, err := s.db.Query(`
		SELECT id, name, channel, subject_template, body_template, created_at, updated_at
		FROM notifications.templates ORDER BY created_at DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []Template
	for rows.Next() {
		var t Template
		if err := rows.Scan(&t.ID, &t.Name, &t.Channel, &t.SubjectTemplate, &t.BodyTemplate,
			&t.CreatedAt, &t.UpdatedAt); err != nil {
			return nil, err
		}
		list = append(list, t)
	}
	return list, nil
}

func (s *Store) UpdateTemplate(t *Template) error {
	_, err := s.db.Exec(`
		UPDATE notifications.templates
		SET name = $1, channel = $2, subject_template = $3, body_template = $4, updated_at = $5
		WHERE id = $6`,
		t.Name, t.Channel, t.SubjectTemplate, t.BodyTemplate, t.UpdatedAt, t.ID)
	return err
}

func (s *Store) DeleteTemplate(id string) error {
	_, err := s.db.Exec(`DELETE FROM notifications.templates WHERE id = $1`, id)
	return err
}

// ---- Database bootstrap ----

func ConnectDB(dsn string) (*sql.DB, error) {
	var db *sql.DB
	var err error
	for i := 0; i < 10; i++ {
		db, err = sql.Open("postgres", dsn)
		if err == nil {
			if pingErr := db.Ping(); pingErr == nil {
				db.SetMaxOpenConns(25)
				db.SetMaxIdleConns(5)
				db.SetConnMaxLifetime(5 * time.Minute)
				log.Println("[INFO] Database connected")
				return db, nil
			}
		}
		log.Printf("[WARN] DB attempt %d/10...", i+1)
		time.Sleep(3 * time.Second)
	}
	return nil, fmt.Errorf("db connect failed after 10 attempts: %w", err)
}

func RunMigrations(db *sql.DB) error {
	schema := `
	CREATE SCHEMA IF NOT EXISTS notifications;

	CREATE TABLE IF NOT EXISTS notifications.templates (
		id               TEXT PRIMARY KEY,
		name             TEXT NOT NULL,
		channel          TEXT NOT NULL,
		subject_template TEXT NOT NULL DEFAULT '',
		body_template    TEXT NOT NULL DEFAULT '',
		created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
		updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
	);

	CREATE TABLE IF NOT EXISTS notifications.notifications (
		id         TEXT PRIMARY KEY,
		channel    TEXT NOT NULL,
		recipient  TEXT NOT NULL,
		subject    TEXT NOT NULL DEFAULT '',
		body       TEXT NOT NULL DEFAULT '',
		status     TEXT NOT NULL DEFAULT 'pending',
		error_msg  TEXT DEFAULT '',
		metadata   JSONB DEFAULT '{}',
		created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
		sent_at    TIMESTAMPTZ
	);

	CREATE INDEX IF NOT EXISTS idx_notifications_status
		ON notifications.notifications(status);
	CREATE INDEX IF NOT EXISTS idx_notifications_created
		ON notifications.notifications(created_at DESC);
	CREATE INDEX IF NOT EXISTS idx_notifications_recipient
		ON notifications.notifications(recipient);
	`
	if _, err := db.Exec(schema); err != nil {
		return fmt.Errorf("notification migrations: %w", err)
	}
	log.Println("[INFO] Migrations applied")
	return nil
}
