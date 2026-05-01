package main

import (
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"strconv"
	"time"

	"github.com/google/uuid"
)

// Handler holds dependencies for all HTTP endpoints.
type Handler struct {
	store      *Store
	dispatcher *Dispatcher
	sbConsumer *AzureServiceBusNotificationConsumer
}

func NewHandler(store *Store, dispatcher *Dispatcher, sbConsumer *AzureServiceBusNotificationConsumer) *Handler {
	return &Handler{store: store, dispatcher: dispatcher, sbConsumer: sbConsumer}
}

// RegisterRoutes wires all endpoints onto the provided mux.
func (h *Handler) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("GET /health", h.Health)

	// Notifications
	mux.HandleFunc("POST /api/v1/notifications/send", h.SendNotification)
	mux.HandleFunc("GET /api/v1/notifications", h.ListNotifications)
	mux.HandleFunc("GET /api/v1/notifications/{id}", h.GetNotification)

	// Templates
	mux.HandleFunc("POST /api/v1/templates", h.CreateTemplate)
	mux.HandleFunc("GET /api/v1/templates", h.ListTemplates)
	mux.HandleFunc("GET /api/v1/templates/{id}", h.GetTemplate)
	mux.HandleFunc("PUT /api/v1/templates/{id}", h.UpdateTemplate)
	mux.HandleFunc("DELETE /api/v1/templates/{id}", h.DeleteTemplate)
}

// ---- Health ----

func (h *Handler) Health(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"status":               "ok",
		"service":              "notification-service",
		"sb_notification_conn": h.sbConsumer != nil && h.sbConsumer.IsConnected(),
	})
}

// ---- Notifications ----

func (h *Handler) SendNotification(w http.ResponseWriter, r *http.Request) {
	var req NotificationRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, APIResponse{Error: "invalid JSON: " + err.Error()})
		return
	}

	if err := h.dispatcher.Process(r.Context(), &req); err != nil {
		writeJSON(w, http.StatusInternalServerError, APIResponse{Error: err.Error()})
		return
	}

	writeJSON(w, http.StatusOK, APIResponse{Message: "notification sent"})
}

func (h *Handler) ListNotifications(w http.ResponseWriter, r *http.Request) {
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))
	if limit <= 0 || limit > 100 {
		limit = 20
	}

	list, err := h.store.ListNotifications(limit, offset)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, APIResponse{Error: err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, APIResponse{Data: list})
}

func (h *Handler) GetNotification(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	n, err := h.store.GetNotification(id)
	if err == sql.ErrNoRows {
		writeJSON(w, http.StatusNotFound, APIResponse{Error: "notification not found"})
		return
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, APIResponse{Error: err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, APIResponse{Data: n})
}

// ---- Templates ----

func (h *Handler) CreateTemplate(w http.ResponseWriter, r *http.Request) {
	var req CreateTemplateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, APIResponse{Error: "invalid JSON: " + err.Error()})
		return
	}
	if req.Name == "" || req.Channel == "" {
		writeJSON(w, http.StatusBadRequest, APIResponse{Error: "name and channel are required"})
		return
	}

	now := time.Now().UTC()
	t := &Template{
		ID:              uuid.New().String(),
		Name:            req.Name,
		Channel:         req.Channel,
		SubjectTemplate: req.SubjectTemplate,
		BodyTemplate:    req.BodyTemplate,
		CreatedAt:       now,
		UpdatedAt:       now,
	}

	if err := h.store.CreateTemplate(t); err != nil {
		writeJSON(w, http.StatusInternalServerError, APIResponse{Error: err.Error()})
		return
	}
	writeJSON(w, http.StatusCreated, APIResponse{Message: "template created", Data: t})
}

func (h *Handler) ListTemplates(w http.ResponseWriter, r *http.Request) {
	list, err := h.store.ListTemplates()
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, APIResponse{Error: err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, APIResponse{Data: list})
}

func (h *Handler) GetTemplate(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	t, err := h.store.GetTemplate(id)
	if err == sql.ErrNoRows {
		writeJSON(w, http.StatusNotFound, APIResponse{Error: "template not found"})
		return
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, APIResponse{Error: err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, APIResponse{Data: t})
}

func (h *Handler) UpdateTemplate(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")

	existing, err := h.store.GetTemplate(id)
	if err == sql.ErrNoRows {
		writeJSON(w, http.StatusNotFound, APIResponse{Error: "template not found"})
		return
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, APIResponse{Error: err.Error()})
		return
	}

	var req UpdateTemplateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, APIResponse{Error: "invalid JSON: " + err.Error()})
		return
	}

	// Merge: only overwrite fields that are provided.
	if req.Name != "" {
		existing.Name = req.Name
	}
	if req.Channel != "" {
		existing.Channel = req.Channel
	}
	if req.SubjectTemplate != "" {
		existing.SubjectTemplate = req.SubjectTemplate
	}
	if req.BodyTemplate != "" {
		existing.BodyTemplate = req.BodyTemplate
	}
	existing.UpdatedAt = time.Now().UTC()

	if err := h.store.UpdateTemplate(existing); err != nil {
		writeJSON(w, http.StatusInternalServerError, APIResponse{Error: err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, APIResponse{Message: "template updated", Data: existing})
}

func (h *Handler) DeleteTemplate(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if err := h.store.DeleteTemplate(id); err != nil {
		writeJSON(w, http.StatusInternalServerError, APIResponse{Error: err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, APIResponse{Message: "template deleted"})
}

// ---- helpers ----

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	if err := json.NewEncoder(w).Encode(v); err != nil {
		log.Printf("[ERROR] writeJSON: %v", err)
	}
}
