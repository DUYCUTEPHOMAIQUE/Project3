package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

const baseURL = "http://localhost:8080/api/v1"

type Response struct {
	Data  interface{} `json:"-"`
	Error string      `json:"error,omitempty"`
}

func main() {
	fmt.Println("=== Testing Key Service API ===\n")

	var aliceToken, bobToken string

	fmt.Println("1. Register Alice user...")
	aliceUserID := registerUser("alice_user", "SecurePass123", "alice@example.com")
	fmt.Printf("Alice User ID: %s\n\n", aliceUserID)

	fmt.Println("2. Register Bob user...")
	bobUserID := registerUser("bob_user", "SecurePass123", "bob@example.com")
	fmt.Printf("Bob User ID: %s\n\n", bobUserID)

	fmt.Println("3. Alice login...")
	aliceToken = login("alice_user", "SecurePass123")
	fmt.Printf("Alice Token: %s...\n\n", aliceToken[:50])

	fmt.Println("4. Bob login...")
	bobToken = login("bob_user", "SecurePass123")
	fmt.Printf("Bob Token: %s...\n\n", bobToken[:50])

	fmt.Println("5. Alice register device...")
	registerDevice(aliceToken, "alice-device-1", aliceUserID,
		"a1b2c3d4e5f67890123456789012345678901234567890123456789012345678",
		"f1e2d3c4b5a67890123456789012345678901234567890123456789012345678",
		"1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
		[]string{
			"9876543210fedcba9876543210fedcba9876543210fedcba9876543210fedcba",
			"abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
		})
	fmt.Println()

	fmt.Println("6. Bob register device...")
	registerDevice(bobToken, "bob-device-1", bobUserID,
		"b1c2d3e4f5a67890123456789012345678901234567890123456789012345678",
		"e1f2a3b4c5d67890123456789012345678901234567890123456789012345678",
		"abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
		[]string{
			"1111111111111111111111111111111111111111111111111111111111111111",
			"2222222222222222222222222222222222222222222222222222222222222222",
		})
	fmt.Println()

	fmt.Println("7. Alice get Bob prekey bundle...")
	getPrekeyBundle(aliceToken, "bob-device-1")
	fmt.Println()

	fmt.Println("8. Bob get Alice prekey bundle...")
	getPrekeyBundle(bobToken, "alice-device-1")
	fmt.Println()

	fmt.Println("=== Test Complete ===")
}

func registerUser(username, password, email string) string {
	reqBody := map[string]interface{}{
		"username": username,
		"password": password,
		"email":    email,
	}
	body, _ := json.Marshal(reqBody)

	resp := makeRequest("POST", baseURL+"/auth/register", nil, body)
	if resp == nil {
		return ""
	}
	printJSON(resp)

	var result map[string]interface{}
	json.Unmarshal(resp, &result)
	if userID, ok := result["user_id"].(string); ok {
		return userID
	}
	return ""
}

func login(username, password string) string {
	reqBody := map[string]interface{}{
		"username": username,
		"password": password,
	}
	body, _ := json.Marshal(reqBody)

	resp := makeRequest("POST", baseURL+"/auth/login", nil, body)
	if resp == nil {
		return ""
	}
	printJSON(resp)

	var result map[string]interface{}
	json.Unmarshal(resp, &result)
	if token, ok := result["access_token"].(string); ok {
		return token
	}
	return ""
}

func registerDevice(token, deviceID, userID, identityKey, signedPrekeyPub, signature string, prekeys []string) {
	prekeysArr := make([]map[string]interface{}, len(prekeys))
	for i, pk := range prekeys {
		prekeysArr[i] = map[string]interface{}{
			"id":         i + 1,
			"public_key": pk,
		}
	}

	reqBody := map[string]interface{}{
		"device_id":          deviceID,
		"user_id":            userID,
		"identity_public_key": identityKey,
		"signed_prekey": map[string]interface{}{
			"id":        1,
			"public_key": signedPrekeyPub,
			"signature":  signature,
			"timestamp": time.Now().Unix(),
		},
		"prekeys": prekeysArr,
	}
	body, _ := json.Marshal(reqBody)

	headers := map[string]string{
		"Authorization": "Bearer " + token,
	}

	resp := makeRequest("POST", baseURL+"/devices/register", headers, body)
	printJSON(resp)
}

func getPrekeyBundle(token, deviceID string) {
	headers := map[string]string{
		"Authorization": "Bearer " + token,
	}

	resp := makeRequest("GET", baseURL+"/devices/"+deviceID+"/prekey-bundle", headers, nil)
	printJSON(resp)
}

func makeRequest(method, url string, headers map[string]string, body []byte) []byte {
	client := &http.Client{Timeout: 10 * time.Second}

	var reqBody io.Reader
	if body != nil {
		reqBody = bytes.NewBuffer(body)
	}

	req, err := http.NewRequest(method, url, reqBody)
	if err != nil {
		fmt.Printf("Error creating request: %v\n", err)
		return nil
	}
	req.Header.Set("Content-Type", "application/json")

	for k, v := range headers {
		req.Header.Set(k, v)
	}

	resp, err := client.Do(req)
	if err != nil {
		fmt.Printf("Error: %v\n", err)
		return nil
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	return respBody
}

func printJSON(data []byte) {
	var prettyJSON bytes.Buffer
	json.Indent(&prettyJSON, data, "", "  ")
	fmt.Println(prettyJSON.String())
}
