package main

import "time"

// Role defines the user's permission level in the system.
type Role string

const (
	RoleAdmin     Role = "Admin"
	RoleAgromist  Role = "Agromist"
)

// User represents a registered user in the IAM service.
type User struct {
	ID           string    `json:"id" db:"id"`
	Email        string    `json:"email" db:"email"`
	PasswordHash string    `json:"-" db:"password_hash"`
	Role         Role      `json:"role" db:"role"`
	FullName     string    `json:"full_name" db:"full_name"`
	Phone        string    `json:"phone,omitempty" db:"phone"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
	UpdatedAt    time.Time `json:"updated_at" db:"updated_at"`
}

// RegisterRequest is the payload for creating a new user.
type RegisterRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=8"`
	FullName string `json:"full_name" binding:"required"`
	Phone    string `json:"phone"`
	Role     Role   `json:"role"`
}

// LoginRequest is the payload for user authentication.
type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

// LoginResponse is the payload returned after successful authentication.
type LoginResponse struct {
	Token     string    `json:"token"`
	ExpiresAt time.Time `json:"expires_at"`
	User      UserDTO   `json:"user"`
}

// UserDTO is the safe, serializable user object returned to clients.
type UserDTO struct {
	ID       string `json:"id"`
	Email    string `json:"email"`
	FullName string `json:"full_name"`
	Role     Role   `json:"role"`
}

// IntrospectResponse is the payload returned from the token validation endpoint.
type IntrospectResponse struct {
	Valid     bool   `json:"valid"`
	UserID    string `json:"user_id,omitempty"`
	Email     string `json:"email,omitempty"`
	Role      Role   `json:"role,omitempty"`
	ExpiresAt int64  `json:"expires_at,omitempty"`
}

// UpdateProfileRequest allows users to update their contact info.
type UpdateProfileRequest struct {
	FullName string `json:"full_name"`
	Phone    string `json:"phone"`
}

// Claims represents the JWT payload structure.
type Claims struct {
	UserID string `json:"user_id"`
	Email  string `json:"email"`
	Role   Role   `json:"role"`
}

// ErrorResponse is the standard error payload.
type ErrorResponse struct {
	Error   string `json:"error"`
	Message string `json:"message,omitempty"`
}

// SuccessResponse is the standard success payload.
type SuccessResponse struct {
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
}
