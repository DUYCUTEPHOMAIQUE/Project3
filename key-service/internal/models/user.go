package models

type User struct {
	UserID        string
	Username      string
	Email         *string
	PasswordHash  string
	NakamaUserID  *string // Nakama user ID, được tạo tự động khi register
	NakamaSession *string // Nakama session token (optional, có thể refresh)
	CreatedAt     int64
}

type UserRegistrationRequest struct {
	Username string  `json:"username" binding:"required"`
	Password string  `json:"password" binding:"required"`
	Email    *string `json:"email"`
}

type UserRegistrationResponse struct {
	UserID         string  `json:"user_id"`
	Username       string  `json:"username"`
	Email          *string `json:"email"`
	NakamaUserID   *string `json:"nakama_user_id,omitempty"`
	NakamaSession  *string `json:"nakama_session,omitempty"`
	CreatedAt      int64   `json:"created_at"`
}

type LoginRequest struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
}

type LoginResponse struct {
	AccessToken   string   `json:"access_token"`
	RefreshToken  string   `json:"refresh_token"`
	TokenType     string   `json:"token_type"`
	ExpiresIn     int      `json:"expires_in"`
	User          UserInfo `json:"user"`
	NakamaUserID  *string  `json:"nakama_user_id,omitempty"`
	NakamaSession *string  `json:"nakama_session,omitempty"`
}

type UserInfo struct {
	UserID   string  `json:"user_id"`
	Username string  `json:"username"`
	Email    *string `json:"email"`
}

type RefreshTokenRequest struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

type RefreshTokenResponse struct {
	AccessToken string `json:"access_token"`
	TokenType   string `json:"token_type"`
	ExpiresIn   int    `json:"expires_in"`
}
