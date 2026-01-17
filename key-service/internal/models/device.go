package models

type DeviceInfo struct {
	DeviceID                    string
	UserID                      string
	IdentityPublicKey           string
	IdentityEd25519VerifyingKey string // Ed25519 verifying key for signature verification
	SignedPrekey                SignedPrekey
	OneTimePrekeys              map[uint32]string
	RegisteredAt                int64
}

type SignedPrekey struct {
	ID        uint32
	PublicKey string
	Signature string
	Timestamp int64
}

type DeviceRegistrationRequest struct {
	DeviceID                    string                 `json:"device_id" binding:"required"`
	UserID                      *string                `json:"user_id"`
	IdentityPublicKey           string                 `json:"identity_public_key" binding:"required"`
	IdentityEd25519VerifyingKey string                 `json:"identity_ed25519_verifying_key" binding:"required"`
	SignedPrekey                SignedPrekeyRequest    `json:"signed_prekey" binding:"required"`
	Prekeys                     []OneTimePrekeyRequest `json:"prekeys" binding:"required,min=1"`
}

type SignedPrekeyRequest struct {
	ID        uint32 `json:"id" binding:"required"`
	PublicKey string `json:"public_key" binding:"required"`
	Signature string `json:"signature" binding:"required"`
	Timestamp int64  `json:"timestamp" binding:"required"`
}

type OneTimePrekeyRequest struct {
	ID        uint32 `json:"id" binding:"required"`
	PublicKey string `json:"public_key" binding:"required"`
}

type DeviceRegistrationResponse struct {
	DeviceID          string `json:"device_id"`
	RegistrationToken string `json:"registration_token"`
	Timestamp         int64  `json:"timestamp"`
}

type PrekeyBundleResponse struct {
	IdentityKey                 string                 `json:"identity_key"`
	IdentityEd25519VerifyingKey string                 `json:"identity_ed25519_verifying_key"`
	SignedPrekey                SignedPrekeyResponse   `json:"signed_prekey"`
	OneTimePrekey               *OneTimePrekeyResponse `json:"one_time_prekey,omitempty"`
}

type SignedPrekeyResponse struct {
	ID        uint32 `json:"id"`
	PublicKey string `json:"public_key"`
	Signature string `json:"signature"`
	Timestamp int64  `json:"timestamp"`
}

type OneTimePrekeyResponse struct {
	ID        uint32 `json:"id"`
	PublicKey string `json:"public_key"`
}
