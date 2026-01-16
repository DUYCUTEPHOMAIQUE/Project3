package utils

import (
	"crypto/rand"
	"encoding/hex"
	"regexp"
	"strings"
)

var (
	usernameRegex = regexp.MustCompile(`^[a-zA-Z0-9_]{3,50}$`)
	emailRegex    = regexp.MustCompile(`^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$`)
	hexRegex      = regexp.MustCompile(`^[0-9a-fA-F]+$`)
)

func ValidateUsername(username string) bool {
	return usernameRegex.MatchString(username)
}

func ValidateEmail(email string) bool {
	return emailRegex.MatchString(email)
}

func ValidatePassword(password string) bool {
	if len(password) < 8 {
		return false
	}
	hasLetter := false
	hasNumber := false
	for _, char := range password {
		if (char >= 'a' && char <= 'z') || (char >= 'A' && char <= 'Z') {
			hasLetter = true
		}
		if char >= '0' && char <= '9' {
			hasNumber = true
		}
	}
	return hasLetter && hasNumber
}

func ValidateHexString(s string, expectedLength int) bool {
	if len(s) != expectedLength {
		return false
	}
	return hexRegex.MatchString(s)
}

func GenerateRegistrationToken() string {
	bytes := make([]byte, 32)
	rand.Read(bytes)
	return hex.EncodeToString(bytes)
}

func NormalizeHex(s string) string {
	return strings.ToLower(s)
}
