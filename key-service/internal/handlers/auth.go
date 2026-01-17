package handlers

import (
	"key-service/internal/models"
	"key-service/internal/services"
	"key-service/internal/storage"
	"key-service/internal/utils"
	"log"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type AuthHandler struct {
	store        *storage.MemoryStorage
	nakamaClient *services.NakamaClient
}

func NewAuthHandler(store *storage.MemoryStorage) *AuthHandler {
	return &AuthHandler{
		store:        store,
		nakamaClient: services.NewNakamaClient(),
	}
}

func (h *AuthHandler) Register(c *gin.Context) {
	var req models.UserRegistrationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if !utils.ValidateUsername(req.Username) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "username is required and must be 3-50 characters"})
		return
	}

	if !utils.ValidatePassword(req.Password) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "password must be at least 8 characters"})
		return
	}

	if req.Email != nil && !utils.ValidateEmail(*req.Email) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "email must be a valid email address"})
		return
	}

	passwordHash, err := utils.HashPassword(req.Password)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to hash password"})
		return
	}

	user := &models.User{
		UserID:       uuid.New().String(),
		Username:     req.Username,
		Email:        req.Email,
		PasswordHash: passwordHash,
		CreatedAt:    time.Now().Unix(),
	}

	if err := h.store.CreateUser(user); err != nil {
		if err == storage.ErrUserExists {
			c.JSON(http.StatusConflict, gin.H{"error": "Username already exists"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user"})
		return
	}

	// Tự động tạo Nakama user
	// Use user_id as custom ID (Nakama requires 6-128 bytes, UUID is 36 bytes which is valid)
	log.Printf("[Nakama] Attempting to create user for username: %s, user_id: %s", user.Username, user.UserID)
	nakamaResp, err := h.nakamaClient.AuthenticateCustom(user.UserID, user.Username)
	if err != nil {
		// Log error nhưng không fail registration
		// User đã được tạo trong Key Service, Nakama có thể được setup sau
		log.Printf("[Nakama] Failed to create Nakama user: %v", err)
		c.JSON(http.StatusCreated, models.UserRegistrationResponse{
			UserID:    user.UserID,
			Username:  user.Username,
			Email:     user.Email,
			CreatedAt: user.CreatedAt,
		})
		return
	}
	log.Printf("[Nakama] Successfully created Nakama user, token: %s...", nakamaResp.Token[:20])

	// Get account info để lấy user ID
	accountInfo, err := h.nakamaClient.GetAccount(nakamaResp.Token)
	var nakamaUserID string
	if err == nil {
		if userID, ok := accountInfo["user"].(map[string]interface{})["id"].(string); ok {
			nakamaUserID = userID
			log.Printf("[Nakama] Got user ID from account: %s", nakamaUserID)
		}
	} else {
		log.Printf("[Nakama] Failed to get account info: %v", err)
	}

	nakamaSession := nakamaResp.Token
	if nakamaUserID != "" {
		user.NakamaUserID = &nakamaUserID
	}
	user.NakamaSession = &nakamaSession

	// Update user trong storage với Nakama info
	if err := h.store.UpdateUser(user); err != nil {
		// Log error nhưng vẫn trả về success response với Nakama info
		// User đã được tạo, chỉ là update storage failed
	}

	c.JSON(http.StatusCreated, models.UserRegistrationResponse{
		UserID:        user.UserID,
		Username:      user.Username,
		Email:         user.Email,
		NakamaUserID:  &nakamaUserID,
		NakamaSession: &nakamaSession,
		CreatedAt:     user.CreatedAt,
	})
}

func (h *AuthHandler) Login(c *gin.Context) {
	var req models.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "username and password are required"})
		return
	}

	user, err := h.store.GetUserByUsername(req.Username)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid username or password"})
		return
	}

	if !utils.CheckPasswordHash(req.Password, user.PasswordHash) {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid username or password"})
		return
	}

	accessToken, err := utils.GenerateAccessToken(user.UserID, user.Username)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate token"})
		return
	}

	refreshToken, err := utils.GenerateRefreshToken(user.UserID, user.Username)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate token"})
		return
	}

	// Nếu user đã có Nakama account, refresh Nakama session
	var nakamaUserID *string
	var nakamaSession *string

	if user.NakamaUserID != nil && *user.NakamaUserID != "" {
		nakamaUserID = user.NakamaUserID
		// Nếu có Nakama session cũ, authenticate lại để get fresh session
		// Use user_id as custom ID (Nakama requires 6-128 bytes, JWT token is too long)
		log.Printf("[Nakama] Refreshing session for existing user: %s", user.Username)
		nakamaResp, err := h.nakamaClient.AuthenticateCustom(user.UserID, user.Username)
		if err == nil {
			nakamaSession = &nakamaResp.Token
			log.Printf("[Nakama] Successfully refreshed session: %s...", nakamaResp.Token[:20])
			// Get account info để lấy user ID nếu chưa có
			if user.NakamaUserID == nil || *user.NakamaUserID == "" {
				accountInfo, err := h.nakamaClient.GetAccount(nakamaResp.Token)
				if err == nil {
					if userID, ok := accountInfo["user"].(map[string]interface{})["id"].(string); ok {
						nakamaUserID = &userID
						user.NakamaUserID = nakamaUserID
					}
				}
			}
			// Update Nakama session trong user record
			user.NakamaSession = nakamaSession
			h.store.UpdateUser(user) // Update storage
		} else {
			log.Printf("[Nakama] Failed to refresh session: %v", err)
		}
	} else {
		// User chưa có Nakama account, tạo mới
		// Use user_id as custom ID (Nakama requires 6-128 bytes, JWT token is too long)
		log.Printf("[Nakama] Creating new Nakama account for user: %s", user.Username)
		nakamaResp, err := h.nakamaClient.AuthenticateCustom(user.UserID, user.Username)
		if err == nil {
			nakamaSession = &nakamaResp.Token
			log.Printf("[Nakama] Successfully created Nakama account: %s...", nakamaResp.Token[:20])
			// Get account info để lấy user ID
			accountInfo, err := h.nakamaClient.GetAccount(nakamaResp.Token)
			if err == nil {
				if userID, ok := accountInfo["user"].(map[string]interface{})["id"].(string); ok {
					nakamaUserID = &userID
					user.NakamaUserID = nakamaUserID
					log.Printf("[Nakama] Got Nakama user ID: %s", userID)
				}
			} else {
				log.Printf("[Nakama] Failed to get account info: %v", err)
			}
			user.NakamaSession = nakamaSession
			h.store.UpdateUser(user) // Update storage
		} else {
			log.Printf("[Nakama] Failed to create Nakama account: %v", err)
		}
	}

	c.JSON(http.StatusOK, models.LoginResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		TokenType:    "Bearer",
		ExpiresIn:    86400,
		User: models.UserInfo{
			UserID:   user.UserID,
			Username: user.Username,
			Email:    user.Email,
		},
		NakamaUserID:  nakamaUserID,
		NakamaSession: nakamaSession,
	})
}

func (h *AuthHandler) Refresh(c *gin.Context) {
	var req models.RefreshTokenRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "refresh_token is required"})
		return
	}

	claims, err := utils.ValidateToken(req.RefreshToken)
	if err != nil || claims.Type != "refresh" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid or expired refresh token"})
		return
	}

	accessToken, err := utils.GenerateAccessToken(claims.UserID, claims.Username)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate token"})
		return
	}

	c.JSON(http.StatusOK, models.RefreshTokenResponse{
		AccessToken: accessToken,
		TokenType:   "Bearer",
		ExpiresIn:   86400,
	})
}
