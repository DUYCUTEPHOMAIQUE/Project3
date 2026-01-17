// package main

// import (
// 	"bytes"
// 	"encoding/json"
// 	"fmt"
// 	"io"
// 	"net/http"
// 	"time"
// )

// const baseURL = "http://localhost:8080/api/v1"

// func main() {
// 	fmt.Println("=== Testing Friend API Endpoints ===\n")

// 	var aliceToken, bobToken, charlieToken string
// 	var aliceUserID, bobUserID, charlieUserID string

// 	// 1. Register users
// 	fmt.Println("1. Register Alice...")
// 	aliceUserID = registerUser("alice_friend", "SecurePass123", "alice@test.com")
// 	fmt.Printf("Alice User ID: %s\n\n", aliceUserID)

// 	fmt.Println("2. Register Bob...")
// 	bobUserID = registerUser("bob_friend", "SecurePass123", "bob@test.com")
// 	fmt.Printf("Bob User ID: %s\n\n", bobUserID)

// 	fmt.Println("3. Register Charlie...")
// 	charlieUserID = registerUser("charlie_friend", "SecurePass123", "charlie@test.com")
// 	fmt.Printf("Charlie User ID: %s\n\n", charlieUserID)

// 	// 2. Login users
// 	fmt.Println("4. Alice login...")
// 	aliceToken = login("alice_friend", "SecurePass123")
// 	fmt.Printf("Alice Token: %s...\n\n", aliceToken[:50])

// 	fmt.Println("5. Bob login...")
// 	bobToken = login("bob_friend", "SecurePass123")
// 	fmt.Printf("Bob Token: %s...\n\n", bobToken[:50])

// 	fmt.Println("6. Charlie login...")
// 	charlieToken = login("charlie_friend", "SecurePass123")
// 	fmt.Printf("Charlie Token: %s...\n\n", charlieToken[:50])

// 	// 3. Test Send Friend Request
// 	fmt.Println("7. Alice sends friend request to Bob...")
// 	requestID1 := sendFriendRequest(aliceToken, "bob_friend", "")
// 	fmt.Printf("Request ID: %s\n\n", requestID1)

// 	fmt.Println("8. Alice sends friend request to Charlie...")
// 	requestID2 := sendFriendRequest(aliceToken, "charlie_friend", "")
// 	fmt.Printf("Request ID: %s\n\n", requestID2)

// 	// 4. Test Get Friend Requests (received)
// 	fmt.Println("9. Bob gets pending friend requests...")
// 	getFriendRequests(bobToken)

// 	// 5. Test Get Sent Friend Requests
// 	fmt.Println("10. Alice gets sent friend requests...")
// 	getSentFriendRequests(aliceToken)

// 	// 6. Test Accept Friend Request
// 	fmt.Println("11. Bob accepts Alice's friend request...")
// 	acceptFriendRequest(bobToken, requestID1)

// 	// 7. Test Reject Friend Request
// 	fmt.Println("12. Charlie rejects Alice's friend request...")
// 	rejectFriendRequest(charlieToken, requestID2)

// 	// 8. Test Get Friends List
// 	fmt.Println("13. Alice gets friends list...")
// 	getFriends(aliceToken)

// 	fmt.Println("14. Bob gets friends list...")
// 	getFriends(bobToken)

// 	// 9. Test Remove Friend
// 	fmt.Println("15. Alice removes Bob from friends...")
// 	removeFriend(aliceToken, bobUserID)

// 	fmt.Println("16. Alice gets friends list after removal...")
// 	getFriends(aliceToken)

// 	// 10. Test edge cases
// 	fmt.Println("17. Alice tries to send friend request to herself...")
// 	sendFriendRequestError(aliceToken, "alice_friend", "")

// 	fmt.Println("18. Alice tries to send duplicate friend request to Bob...")
// 	sendFriendRequestError(aliceToken, "bob_friend", "")

// 	fmt.Println("=== Test Complete ===")
// }

// func registerUser(username, password, email string) string {
// 	reqBody := map[string]interface{}{
// 		"username": username,
// 		"password": password,
// 		"email":    email,
// 	}
// 	body, _ := json.Marshal(reqBody)

// 	resp := makeRequest("POST", baseURL+"/auth/register", nil, body)
// 	if resp == nil {
// 		return ""
// 	}
// 	printJSON(resp)

// 	var result map[string]interface{}
// 	json.Unmarshal(resp, &result)
// 	if userID, ok := result["user_id"].(string); ok {
// 		return userID
// 	}
// 	return ""
// }

// func login(username, password string) string {
// 	reqBody := map[string]interface{}{
// 		"username": username,
// 		"password": password,
// 	}
// 	body, _ := json.Marshal(reqBody)

// 	resp := makeRequest("POST", baseURL+"/auth/login", nil, body)
// 	if resp == nil {
// 		return ""
// 	}
// 	printJSON(resp)

// 	var result map[string]interface{}
// 	json.Unmarshal(resp, &result)
// 	if token, ok := result["access_token"].(string); ok {
// 		return token
// 	}
// 	return ""
// }

// func sendFriendRequest(token, username, email string) string {
// 	reqBody := make(map[string]interface{})
// 	if username != "" {
// 		reqBody["username"] = username
// 	}
// 	if email != "" {
// 		reqBody["email"] = email
// 	}
// 	body, _ := json.Marshal(reqBody)

// 	headers := map[string]string{
// 		"Authorization": "Bearer " + token,
// 	}

// 	resp := makeRequest("POST", baseURL+"/friends/request", headers, body)
// 	if resp == nil {
// 		return ""
// 	}
// 	printJSON(resp)

// 	var result map[string]interface{}
// 	json.Unmarshal(resp, &result)
// 	if requestID, ok := result["request_id"].(string); ok {
// 		return requestID
// 	}
// 	return ""
// }

// func sendFriendRequestError(token, username, email string) {
// 	reqBody := make(map[string]interface{})
// 	if username != "" {
// 		reqBody["username"] = username
// 	}
// 	if email != "" {
// 		reqBody["email"] = email
// 	}
// 	body, _ := json.Marshal(reqBody)

// 	headers := map[string]string{
// 		"Authorization": "Bearer " + token,
// 	}

// 	resp := makeRequest("POST", baseURL+"/friends/request", headers, body)
// 	printJSON(resp)
// }

// func acceptFriendRequest(token, requestID string) {
// 	reqBody := map[string]interface{}{
// 		"request_id": requestID,
// 	}
// 	body, _ := json.Marshal(reqBody)

// 	headers := map[string]string{
// 		"Authorization": "Bearer " + token,
// 	}

// 	resp := makeRequest("POST", baseURL+"/friends/accept", headers, body)
// 	printJSON(resp)
// }

// func rejectFriendRequest(token, requestID string) {
// 	reqBody := map[string]interface{}{
// 		"request_id": requestID,
// 	}
// 	body, _ := json.Marshal(reqBody)

// 	headers := map[string]string{
// 		"Authorization": "Bearer " + token,
// 	}

// 	resp := makeRequest("POST", baseURL+"/friends/reject", headers, body)
// 	printJSON(resp)
// }

// func removeFriend(token, friendUserID string) {
// 	reqBody := map[string]interface{}{
// 		"friend_user_id": friendUserID,
// 	}
// 	body, _ := json.Marshal(reqBody)

// 	headers := map[string]string{
// 		"Authorization": "Bearer " + token,
// 	}

// 	resp := makeRequest("POST", baseURL+"/friends/remove", headers, body)
// 	printJSON(resp)
// }

// func getFriendRequests(token string) {
// 	headers := map[string]string{
// 		"Authorization": "Bearer " + token,
// 	}

// 	resp := makeRequest("GET", baseURL+"/friends/requests", headers, nil)
// 	printJSON(resp)
// }

// func getSentFriendRequests(token string) {
// 	headers := map[string]string{
// 		"Authorization": "Bearer " + token,
// 	}

// 	resp := makeRequest("GET", baseURL+"/friends/requests/sent", headers, nil)
// 	printJSON(resp)
// }

// func getFriends(token string) {
// 	headers := map[string]string{
// 		"Authorization": "Bearer " + token,
// 	}

// 	resp := makeRequest("GET", baseURL+"/friends/list", headers, nil)
// 	printJSON(resp)
// }

// func makeRequest(method, url string, headers map[string]string, body []byte) []byte {
// 	client := &http.Client{Timeout: 10 * time.Second}

// 	var reqBody io.Reader
// 	if body != nil {
// 		reqBody = bytes.NewBuffer(body)
// 	}

// 	req, err := http.NewRequest(method, url, reqBody)
// 	if err != nil {
// 		fmt.Printf("Error creating request: %v\n", err)
// 		return nil
// 	}
// 	req.Header.Set("Content-Type", "application/json")

// 	for k, v := range headers {
// 		req.Header.Set(k, v)
// 	}

// 	resp, err := client.Do(req)
// 	if err != nil {
// 		fmt.Printf("Error: %v\n", err)
// 		return nil
// 	}
// 	defer resp.Body.Close()

// 	respBody, _ := io.ReadAll(resp.Body)
// 	fmt.Printf("Status: %d\n", resp.StatusCode)
// 	return respBody
// }

// func printJSON(data []byte) {
// 	if len(data) == 0 {
// 		fmt.Println("(empty response)")
// 		return
// 	}
// 	var prettyJSON bytes.Buffer
// 	json.Indent(&prettyJSON, data, "", "  ")
// 	fmt.Println(prettyJSON.String())
// }
