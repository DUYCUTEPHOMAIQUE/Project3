package handlers

import (
	"key-service/internal/models"
	"key-service/internal/storage"
	"key-service/internal/utils"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

type DeviceHandler struct {
	store *storage.MemoryStorage
}

func NewDeviceHandler(store *storage.MemoryStorage) *DeviceHandler {
	return &DeviceHandler{store: store}
}

func (h *DeviceHandler) Register(c *gin.Context) {
	var req models.DeviceRegistrationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	userID, _ := c.Get("user_id")
	uid := userID.(string)
	req.UserID = &uid

	req.IdentityPublicKey = utils.NormalizeHex(req.IdentityPublicKey)
	req.IdentityEd25519VerifyingKey = utils.NormalizeHex(req.IdentityEd25519VerifyingKey)
	req.SignedPrekey.PublicKey = utils.NormalizeHex(req.SignedPrekey.PublicKey)
	req.SignedPrekey.Signature = utils.NormalizeHex(req.SignedPrekey.Signature)

	if !utils.ValidateHexString(req.IdentityPublicKey, 64) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "identity_public_key must be a valid hex string (64 characters)"})
		return
	}

	if !utils.ValidateHexString(req.IdentityEd25519VerifyingKey, 64) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "identity_ed25519_verifying_key must be a valid hex string (64 characters)"})
		return
	}

	if !utils.ValidateHexString(req.SignedPrekey.PublicKey, 64) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "signed_prekey.public_key must be a valid hex string (64 characters)"})
		return
	}

	if !utils.ValidateHexString(req.SignedPrekey.Signature, 128) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "signed_prekey.signature must be a valid hex string (128 characters)"})
		return
	}

	for i := range req.Prekeys {
		req.Prekeys[i].PublicKey = utils.NormalizeHex(req.Prekeys[i].PublicKey)
		if !utils.ValidateHexString(req.Prekeys[i].PublicKey, 64) {
			c.JSON(http.StatusBadRequest, gin.H{"error": "prekeys[].public_key must be a valid hex string (64 characters)"})
			return
		}
	}

	oneTimePrekeys := make(map[uint32]string)
	for _, prekey := range req.Prekeys {
		oneTimePrekeys[prekey.ID] = utils.NormalizeHex(prekey.PublicKey)
	}

	device := &models.DeviceInfo{
		DeviceID:                   req.DeviceID,
		UserID:                     *req.UserID,
		IdentityPublicKey:          utils.NormalizeHex(req.IdentityPublicKey),
		IdentityEd25519VerifyingKey: utils.NormalizeHex(req.IdentityEd25519VerifyingKey),
		SignedPrekey: models.SignedPrekey{
			ID:        req.SignedPrekey.ID,
			PublicKey: utils.NormalizeHex(req.SignedPrekey.PublicKey),
			Signature: utils.NormalizeHex(req.SignedPrekey.Signature),
			Timestamp: req.SignedPrekey.Timestamp,
		},
		OneTimePrekeys: oneTimePrekeys,
		RegisteredAt:   time.Now().Unix(),
	}

	if err := h.store.CreateDevice(device); err != nil {
		if err == storage.ErrDeviceExists {
			c.JSON(http.StatusConflict, gin.H{"error": "Device already registered"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to register device"})
		return
	}

	c.JSON(http.StatusCreated, models.DeviceRegistrationResponse{
		DeviceID:         device.DeviceID,
		RegistrationToken: utils.GenerateRegistrationToken(),
		Timestamp:        device.RegisteredAt,
	})
}

func (h *DeviceHandler) GetPrekeyBundle(c *gin.Context) {
	deviceID := c.Param("device_id")
	if deviceID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "device_id is required"})
		return
	}

	device, err := h.store.GetDevice(deviceID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Device not found"})
		return
	}

	oneTimePrekey, _ := h.store.TakeOneTimePrekey(deviceID)

	response := models.PrekeyBundleResponse{
		IdentityKey:                device.IdentityPublicKey,
		IdentityEd25519VerifyingKey: device.IdentityEd25519VerifyingKey,
		SignedPrekey: models.SignedPrekeyResponse{
			ID:        device.SignedPrekey.ID,
			PublicKey: device.SignedPrekey.PublicKey,
			Signature: device.SignedPrekey.Signature,
			Timestamp: device.SignedPrekey.Timestamp,
		},
	}

	if oneTimePrekey != nil {
		response.OneTimePrekey = oneTimePrekey
	}

	c.JSON(http.StatusOK, response)
}

// GetPrekeyBundleByUserID gets prekey bundle for a user (uses first available device)
func (h *DeviceHandler) GetPrekeyBundleByUserID(c *gin.Context) {
	userID := c.Param("user_id")
	if userID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "user_id is required"})
		return
	}

	// Get all devices for this user
	devices, err := h.store.GetDevicesByUserID(userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "No devices found for user"})
		return
	}

	// Use the first device (or could implement logic to select preferred device)
	device := devices[0]

	oneTimePrekey, _ := h.store.TakeOneTimePrekey(device.DeviceID)

	response := models.PrekeyBundleResponse{
		IdentityKey:                device.IdentityPublicKey,
		IdentityEd25519VerifyingKey: device.IdentityEd25519VerifyingKey,
		SignedPrekey: models.SignedPrekeyResponse{
			ID:        device.SignedPrekey.ID,
			PublicKey: device.SignedPrekey.PublicKey,
			Signature: device.SignedPrekey.Signature,
			Timestamp: device.SignedPrekey.Timestamp,
		},
	}

	if oneTimePrekey != nil {
		response.OneTimePrekey = oneTimePrekey
	}

	c.JSON(http.StatusOK, response)
}

// DeleteDevice deletes a device (only allowed by device owner)
func (h *DeviceHandler) DeleteDevice(c *gin.Context) {
	deviceID := c.Param("device_id")
	if deviceID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "device_id is required"})
		return
	}

	userID, _ := c.Get("user_id")
	uid := userID.(string)

	// Verify device belongs to user
	device, err := h.store.GetDevice(deviceID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Device not found"})
		return
	}

	if device.UserID != uid {
		c.JSON(http.StatusForbidden, gin.H{"error": "Device does not belong to user"})
		return
	}

	// Delete device
	if err := h.store.DeleteDevice(deviceID); err != nil {
		if err == storage.ErrDeviceNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": "Device not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete device"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Device deleted successfully"})
}
