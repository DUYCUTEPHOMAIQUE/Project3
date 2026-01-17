package services

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"
)

// NakamaClient handles communication with Nakama server
type NakamaClient struct {
	baseURL    string
	serverKey  string
	httpClient *http.Client
}

// NakamaAuthResponse represents Nakama authentication response
type NakamaAuthResponse struct {
	Token        string `json:"token"`
	RefreshToken string `json:"refresh_token"`
	Created      bool   `json:"created"`
	// Note: User info is not in auth response, need to call GetAccount() with token
}

// NewNakamaClient creates a new Nakama client
func NewNakamaClient() *NakamaClient {
	nakamaHost := os.Getenv("NAKAMA_HOST")
	if nakamaHost == "" {
		nakamaHost = "127.0.0.1"
	}

	nakamaPort := os.Getenv("NAKAMA_PORT")
	if nakamaPort == "" {
		nakamaPort = "7350"
	}

	serverKey := os.Getenv("NAKAMA_SERVER_KEY")
	if serverKey == "" {
		serverKey = "defaultkey"
	}

	return &NakamaClient{
		baseURL:   fmt.Sprintf("http://%s:%s", nakamaHost, nakamaPort),
		serverKey: serverKey,
		httpClient: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

// AuthenticateCustom authenticates with Nakama using custom token (JWT from Key Service)
func (nc *NakamaClient) AuthenticateCustom(customToken string, username string) (*NakamaAuthResponse, error) {
	url := fmt.Sprintf("%s/v2/account/authenticate/custom", nc.baseURL)

	payload := map[string]interface{}{
		"id":       customToken, // Use JWT token as custom ID
		"username": username,
		"create":   true, // Create user if not exists
	}

	jsonData, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal payload: %w", err)
	}

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	// Nakama uses Basic Auth with server key
	auth := base64.StdEncoding.EncodeToString([]byte(nc.serverKey + ":"))
	req.Header.Set("Authorization", "Basic "+auth)
	req.Header.Set("Content-Type", "application/json")

	resp, err := nc.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		return nil, fmt.Errorf("nakama authentication failed: status %d, body: %s", resp.StatusCode, string(body))
	}

	var authResp NakamaAuthResponse
	if err := json.Unmarshal(body, &authResp); err != nil {
		return nil, fmt.Errorf("failed to unmarshal response: %w", err)
	}

	return &authResp, nil
}

// GetAccount retrieves account information from Nakama
func (nc *NakamaClient) GetAccount(sessionToken string) (map[string]interface{}, error) {
	url := fmt.Sprintf("%s/v2/account", nc.baseURL)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+sessionToken)

	resp, err := nc.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("failed to get account: status %d, body: %s", resp.StatusCode, string(body))
	}

	var account map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&account); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	return account, nil
}
