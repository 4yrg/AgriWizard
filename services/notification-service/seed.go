package main

import (
	"log"
	"time"

	"github.com/google/uuid"
)

func SeedNotifications(store *Store) {
	var count int64
	row := store.db.QueryRow("SELECT COUNT(*) FROM notifications.notifications")
	if err := row.Scan(&count); err != nil {
		log.Printf("[WARN] Seed: cannot count notifications: %v", err)
		return
	}
	if count > 0 {
		log.Printf("[INFO] Seed: %d notifications already exist, skipping", count)
		return
	}

	recipient := "dasunwickramasooriyaoutlook.onmicrosoft.com"
	now := time.Now().UTC()

	seed := []Notification{
		{
			ID:        uuid.New().String(),
			Channel:   "in_app",
			Recipient: recipient,
			Subject:   "Welcome to AgriWizard!",
			Body:      "Your smart greenhouse management system is ready. Explore the dashboard to monitor sensors, control hardware, and view analytics.",
			Status:    "sent",
			Metadata:  map[string]string{"category": "onboarding"},
			CreatedAt: now.Add(-72 * time.Hour),
			SentAt:    timeToPtr(now.Add(-72 * time.Hour)),
		},
		{
			ID:        uuid.New().String(),
			Channel:   "in_app",
			Recipient: recipient,
			Subject:   "Temperature Alert: Greenhouse Zone A",
			Body:      "Temperature has exceeded 35°C in Greenhouse Zone A. Consider activating ventilation or adjusting irrigation to prevent crop stress.",
			Status:    "sent",
			Metadata:  map[string]string{"category": "alert", "zone": "A", "type": "temperature"},
			CreatedAt: now.Add(-48 * time.Hour),
			SentAt:    timeToPtr(now.Add(-48 * time.Hour)),
		},
		{
			ID:        uuid.New().String(),
			Channel:   "in_app",
			Recipient: recipient,
			Subject:   "Soil Moisture Low — Zone B",
			Body:      "Soil moisture in Zone B has dropped below 30%. The irrigation recommendation engine suggests scheduling a watering cycle within the next 2 hours.",
			Status:    "sent",
			Metadata:  map[string]string{"category": "alert", "zone": "B", "type": "soil_moisture"},
			CreatedAt: now.Add(-24 * time.Hour),
			SentAt:    timeToPtr(now.Add(-24 * time.Hour)),
		},
		{
			ID:        uuid.New().String(),
			Channel:   "in_app",
			Recipient: recipient,
			Subject:   "Weekly Analytics Report Ready",
			Body:      "Your weekly greenhouse analytics report is available. Average temperature: 28°C, humidity: 65%, light intensity: 12,000 lux. View the full report in the Analytics dashboard.",
			Status:    "sent",
			Metadata:  map[string]string{"category": "report", "type": "weekly"},
			CreatedAt: now.Add(-12 * time.Hour),
			SentAt:    timeToPtr(now.Add(-12 * time.Hour)),
		},
		{
			ID:        uuid.New().String(),
			Channel:   "in_app",
			Recipient: recipient,
			Subject:   "New Weather Forecast Available",
			Body:      "Heavy rain expected in Colombo over the next 48 hours. Consider adjusting greenhouse ventilation settings and securing outdoor equipment.",
			Status:    "sent",
			Metadata:  map[string]string{"category": "weather", "type": "forecast"},
			CreatedAt: now.Add(-6 * time.Hour),
			SentAt:    timeToPtr(now.Add(-6 * time.Hour)),
		},
		{
			ID:        uuid.New().String(),
			Channel:   "in_app",
			Recipient: recipient,
			Subject:   "Hardware Device Offline",
			Body:      "Sensor node SN-0042 in Zone C has been offline for 15 minutes. Check the hardware status page or attempt a remote restart.",
			Status:    "sent",
			Metadata:  map[string]string{"category": "hardware", "device": "SN-0042", "type": "offline"},
			CreatedAt: now.Add(-3 * time.Hour),
			SentAt:    timeToPtr(now.Add(-3 * time.Hour)),
		},
		{
			ID:        uuid.New().String(),
			Channel:   "in_app",
			Recipient: recipient,
			Subject:   "Irrigation Cycle Completed",
			Body:      "The scheduled irrigation cycle for Zone A has completed successfully. Water usage: 120L. Duration: 25 minutes.",
			Status:    "sent",
			Metadata:  map[string]string{"category": "hardware", "zone": "A", "type": "irrigation"},
			CreatedAt: now.Add(-1 * time.Hour),
			SentAt:    timeToPtr(now.Add(-1 * time.Hour)),
		},
		{
			ID:        uuid.New().String(),
			Channel:   "in_app",
			Recipient: recipient,
			Subject:   "Humidity Threshold Exceeded",
			Body:      "Greenhouse humidity has reached 85% in Zone B, exceeding the configured threshold of 80%. Consider enabling dehumidification or increasing ventilation.",
			Status:    "sent",
			Metadata:  map[string]string{"category": "alert", "zone": "B", "type": "humidity"},
			CreatedAt: now.Add(-30 * time.Minute),
			SentAt:    timeToPtr(now.Add(-30 * time.Minute)),
		},
	}

	for i := range seed {
		if err := store.SaveNotification(&seed[i]); err != nil {
			log.Printf("[ERROR] Seed: failed to insert notification %s: %v", seed[i].ID, err)
		}
	}

	log.Printf("[INFO] Seed: inserted %d sample notifications for %s", len(seed), recipient)
}

func timeToPtr(t time.Time) *time.Time {
	return &t
}
