package main

import (
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"context"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

// Handler holds the database status and config for all handlers.
type Handler struct {
	dbStatus                *DBStatus
	jwtSecret               string
	jwtIssuer               string
	jwtTTL                  time.Duration
	sbNotificationPublisher *AzureServiceBusNotificationPublisher
}

// NewHandler creates a new Handler instance.
func NewHandler(dbStatus *DBStatus, jwtSecret, jwtIssuer string, jwtTTL time.Duration, sbNotificationPublisher *AzureServiceBusNotificationPublisher) *Handler {
	return &Handler{
		dbStatus:                dbStatus,
		jwtSecret:               jwtSecret,
		jwtIssuer:               jwtIssuer,
		jwtTTL:                  jwtTTL,
		sbNotificationPublisher: sbNotificationPublisher,
	}
}

// requireDB is a middleware that checks if the database is ready.
func (h *Handler) requireDB() gin.HandlerFunc {
	return func(c *gin.Context) {
		if !h.dbStatus.IsReady() {
			c.JSON(http.StatusServiceUnavailable, ErrorResponse{
				Error:   "service_unavailable",
				Message: "database connection not ready, please try again later",
			})
			c.Abort()
			return
		}
		c.Next()
	}
}

// Register godoc
// @Summary      Register a new user
// @Description  Creates a new user account with the specified role
// @Tags         auth
// @Accept       json
// @Produce      json
// @Param        body  body      RegisterRequest  true  "Registration payload"
// @Success      201   {object}  SuccessResponse
// @Failure      400   {object}  ErrorResponse
// @Failure      409   {object}  ErrorResponse
// @Router       /api/v1/iam/register [post]
func (h *Handler) Register(c *gin.Context) {
	if !h.dbStatus.IsReady() {
		c.JSON(http.StatusServiceUnavailable, ErrorResponse{Error: "service_unavailable", Message: "database not ready"})
		return
	}
	db := h.dbStatus.GetDB()

	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "invalid_request", Message: err.Error()})
		return
	}

	// Default role to Agromist if not specified
	if req.Role == "" {
		req.Role = RoleAgromist
	}

	// Validate role
	if req.Role != RoleAdmin && req.Role != RoleAgromist {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "invalid_role", Message: "role must be Admin or Agromist"})
		return
	}

	// Check if email already exists
	var existingID string
	err := db.QueryRow(`SELECT id FROM iam.users WHERE email = $1`, req.Email).Scan(&existingID)
	if err == nil {
		c.JSON(http.StatusConflict, ErrorResponse{Error: "email_exists", Message: "a user with this email already exists"})
		return
	}
	if err != sql.ErrNoRows {
		log.Printf("[ERROR] Register: db query: %v", err)
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "db_error"})
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		log.Printf("[ERROR] Register: bcrypt: %v", err)
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "hash_error"})
		return
	}

	userID := uuid.New().String()
	_, err = db.Exec(
		`INSERT INTO iam.users (id, email, password_hash, role, full_name, phone) VALUES ($1, $2, $3, $4, $5, $6)`,
		userID, req.Email, string(hash), string(req.Role), req.FullName, req.Phone,
	)
	if err != nil {
		log.Printf("[ERROR] Register: db insert: %v", err)
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "db_error"})
		return
	}

	log.Printf("[INFO] Register: new user created id=%s email=%s role=%s", userID, req.Email, req.Role)

	// Send notification for new registration
	recipient := getServiceBusNotificationRecipient()
	go h.sendNotification(
		recipient,
		"New user registered",
		fmt.Sprintf("A new user has registered: %s (%s)", req.FullName, req.Email),
		map[string]string{"user_id": userID, "email": req.Email},
	)

	c.JSON(http.StatusCreated, SuccessResponse{
		Message: "user registered successfully",
		Data:    UserDTO{ID: userID, Email: req.Email, FullName: req.FullName, Role: req.Role},
	})
}

// Login godoc
// @Summary      Authenticate user and issue JWT
// @Description  Validates credentials and returns a signed JWT token
// @Tags         auth
// @Accept       json
// @Produce      json
// @Param        body  body      LoginRequest   true  "Login credentials"
// @Success      200   {object}  LoginResponse
// @Failure      400   {object}  ErrorResponse
// @Failure      401   {object}  ErrorResponse
// @Router       /api/v1/iam/login [post]
func (h *Handler) Login(c *gin.Context) {
	if !h.dbStatus.IsReady() {
		c.JSON(http.StatusServiceUnavailable, ErrorResponse{Error: "service_unavailable", Message: "database not ready"})
		return
	}
	db := h.dbStatus.GetDB()

	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "invalid_request", Message: err.Error()})
		return
	}

	var user User
	err := db.QueryRow(
		`SELECT id, email, password_hash, role, full_name, COALESCE(phone, '') FROM iam.users WHERE email = $1`,
		req.Email,
	).Scan(&user.ID, &user.Email, &user.PasswordHash, &user.Role, &user.FullName, &user.Phone)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusUnauthorized, ErrorResponse{Error: "invalid_credentials"})
		return
	}
	if err != nil {
		log.Printf("[ERROR] Login: db query: %v", err)
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "db_error"})
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		c.JSON(http.StatusUnauthorized, ErrorResponse{Error: "invalid_credentials"})
		return
	}

	expiresAt := time.Now().Add(h.jwtTTL)
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"user_id": user.ID,
		"email":   user.Email,
		"role":    string(user.Role),
		"iss":     h.jwtIssuer,
		"exp":     expiresAt.Unix(),
		"iat":     time.Now().Unix(),
	})

	tokenStr, err := token.SignedString([]byte(h.jwtSecret))
	if err != nil {
		log.Printf("[ERROR] Login: jwt sign: %v", err)
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "token_error"})
		return
	}

	log.Printf("[INFO] Login: successful login id=%s role=%s", user.ID, user.Role)
	c.JSON(http.StatusOK, LoginResponse{
		Token:     tokenStr,
		ExpiresAt: expiresAt,
		User:      UserDTO{ID: user.ID, Email: user.Email, FullName: user.FullName, Role: user.Role},
	})
}

// Introspect godoc
// @Summary      Validate a JWT token
// @Description  Used by other microservices to validate Bearer tokens
// @Tags         auth
// @Accept       json
// @Produce      json
// @Security     BearerAuth
// @Success      200   {object}  IntrospectResponse
// @Failure      401   {object}  ErrorResponse
// @Router       /api/v1/iam/introspect [get]
func (h *Handler) Introspect(c *gin.Context) {
	authHeader := c.GetHeader("Authorization")
	if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
		c.JSON(http.StatusOK, IntrospectResponse{Valid: false})
		return
	}

	tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
	token, err := jwt.Parse(tokenStr, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, jwt.ErrSignatureInvalid
		}
		return []byte(h.jwtSecret), nil
	})

	if err != nil || !token.Valid {
		c.JSON(http.StatusOK, IntrospectResponse{Valid: false})
		return
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		c.JSON(http.StatusOK, IntrospectResponse{Valid: false})
		return
	}

	exp, _ := claims["exp"].(float64)
	c.JSON(http.StatusOK, IntrospectResponse{
		Valid:     true,
		UserID:    claims["user_id"].(string),
		Email:     claims["email"].(string),
		Role:      Role(claims["role"].(string)),
		ExpiresAt: int64(exp),
	})
}

// GetProfile godoc
// @Summary      Get current user profile
// @Description  Returns profile for the authenticated user
// @Tags         users
// @Produce      json
// @Security     BearerAuth
// @Success      200   {object}  SuccessResponse
// @Failure      401   {object}  ErrorResponse
// @Router       /api/v1/iam/profile [get]
func (h *Handler) GetProfile(c *gin.Context) {
	if !h.dbStatus.IsReady() {
		c.JSON(http.StatusServiceUnavailable, ErrorResponse{Error: "service_unavailable", Message: "database not ready"})
		return
	}
	db := h.dbStatus.GetDB()

	userID, _ := c.Get("user_id")
	var user User
	err := db.QueryRow(
		`SELECT id, email, role, full_name, COALESCE(phone, ''), created_at FROM iam.users WHERE id = $1`,
		userID,
	).Scan(&user.ID, &user.Email, &user.Role, &user.FullName, &user.Phone, &user.CreatedAt)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, ErrorResponse{Error: "user_not_found"})
		return
	}
	if err != nil {
		log.Printf("[ERROR] GetProfile: %v", err)
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "db_error"})
		return
	}
	c.JSON(http.StatusOK, SuccessResponse{Data: user})
}

// UpdateProfile godoc
// @Summary      Update user profile
// @Description  Updates contact information for the authenticated user
// @Tags         users
// @Accept       json
// @Produce      json
// @Security     BearerAuth
// @Param        body  body      UpdateProfileRequest  true  "Profile update payload"
// @Success      200   {object}  SuccessResponse
// @Failure      400   {object}  ErrorResponse
// @Router       /api/v1/iam/profile [put]
func (h *Handler) UpdateProfile(c *gin.Context) {
	if !h.dbStatus.IsReady() {
		c.JSON(http.StatusServiceUnavailable, ErrorResponse{Error: "service_unavailable", Message: "database not ready"})
		return
	}
	db := h.dbStatus.GetDB()

	userID, _ := c.Get("user_id")
	var req UpdateProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "invalid_request", Message: err.Error()})
		return
	}
	_, err := db.Exec(
		`UPDATE iam.users SET full_name=$1, phone=$2, updated_at=NOW() WHERE id=$3`,
		req.FullName, req.Phone, userID,
	)
	if err != nil {
		log.Printf("[ERROR] UpdateProfile: %v", err)
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "db_error"})
		return
	}
	c.JSON(http.StatusOK, SuccessResponse{Message: "profile updated successfully"})
}

// JWTAuthMiddleware validates the Bearer token on protected routes.
func (h *Handler) JWTAuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
			c.AbortWithStatusJSON(http.StatusUnauthorized, ErrorResponse{Error: "missing_token"})
			return
		}

		tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
		token, err := jwt.Parse(tokenStr, func(t *jwt.Token) (interface{}, error) {
			if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, jwt.ErrSignatureInvalid
			}
			return []byte(h.jwtSecret), nil
		})

		if err != nil || !token.Valid {
			c.AbortWithStatusJSON(http.StatusUnauthorized, ErrorResponse{Error: "invalid_token"})
			return
		}

		claims, _ := token.Claims.(jwt.MapClaims)
		c.Set("user_id", claims["user_id"])
		c.Set("email", claims["email"])
		c.Set("role", claims["role"])
		c.Next()
	}
}

// AdminOnly middleware restricts endpoints to Admin role only.
func AdminOnly() gin.HandlerFunc {
	return func(c *gin.Context) {
		role, _ := c.Get("role")
		if role != string(RoleAdmin) {
			c.AbortWithStatusJSON(http.StatusForbidden, ErrorResponse{Error: "forbidden", Message: "admin role required"})
			return
		}
		c.Next()
	}
}

// sendNotification is a helper to send notifications via Service Bus
func (h *Handler) sendNotification(recipient, subject, body string, metadata map[string]string) {
	if h.sbNotificationPublisher == nil || !h.sbNotificationPublisher.IsConnected() {
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	req := NotificationRequest{
		Channel:   "email",
		Recipient: recipient,
		Subject:   subject,
		Body:      body,
		Metadata:  metadata,
	}

	if err := h.sbNotificationPublisher.PublishNotification(ctx, req); err != nil {
		log.Printf("[WARN] Failed to send notification: %v", err)
	}
}
