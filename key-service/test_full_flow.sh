#!/bin/bash

BASE_URL="http://localhost:8099/api/v1"

echo "=== Testing Full Flow: Register -> Login -> Device Registration -> Friend Request -> Accept -> Get Prekey Bundle ==="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TIMESTAMP=$(date +%s)
USER1_USERNAME="alice_test_${TIMESTAMP}"
USER2_USERNAME="bob_test_${TIMESTAMP}"

echo -e "${YELLOW}1. Register User 1 (Alice)...${NC}"
USER1_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"$USER1_USERNAME\",
    \"password\": \"SecurePass123\",
    \"email\": \"${USER1_USERNAME}@example.com\"
  }")
echo "$USER1_RESPONSE" | jq '.'
USER1_USER_ID=$(echo "$USER1_RESPONSE" | jq -r '.user_id // empty')
if [ -z "$USER1_USER_ID" ]; then
  echo -e "${RED}Failed to register User 1${NC}"
  exit 1
fi
echo -e "${GREEN}User 1 ID: $USER1_USER_ID${NC}"
echo ""

echo -e "${YELLOW}2. Register User 2 (Bob)...${NC}"
USER2_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"$USER2_USERNAME\",
    \"password\": \"SecurePass123\",
    \"email\": \"${USER2_USERNAME}@example.com\"
  }")
echo "$USER2_RESPONSE" | jq '.'
USER2_USER_ID=$(echo "$USER2_RESPONSE" | jq -r '.user_id // empty')
if [ -z "$USER2_USER_ID" ]; then
  echo -e "${RED}Failed to register User 2${NC}"
  exit 1
fi
echo -e "${GREEN}User 2 ID: $USER2_USER_ID${NC}"
echo ""

echo -e "${YELLOW}3. User 1 (Alice) login...${NC}"
USER1_LOGIN=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"$USER1_USERNAME\",
    \"password\": \"SecurePass123\"
  }")
echo "$USER1_LOGIN" | jq '.'
USER1_TOKEN=$(echo "$USER1_LOGIN" | jq -r '.access_token // empty')
if [ -z "$USER1_TOKEN" ]; then
  echo -e "${RED}Failed to login User 1${NC}"
  exit 1
fi
echo -e "${GREEN}User 1 Token: ${USER1_TOKEN:0:50}...${NC}"
echo ""

echo -e "${YELLOW}4. User 2 (Bob) login...${NC}"
USER2_LOGIN=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"$USER2_USERNAME\",
    \"password\": \"SecurePass123\"
  }")
echo "$USER2_LOGIN" | jq '.'
USER2_TOKEN=$(echo "$USER2_LOGIN" | jq -r '.access_token // empty')
if [ -z "$USER2_TOKEN" ]; then
  echo -e "${RED}Failed to login User 2${NC}"
  exit 1
fi
echo -e "${GREEN}User 2 Token: ${USER2_TOKEN:0:50}...${NC}"
echo ""

echo -e "${YELLOW}5. User 1 register device (with Ed25519 verifying key)...${NC}"
USER1_DEVICE_ID="${USER1_USER_ID}-macos"
USER1_DEVICE=$(curl -s -X POST "$BASE_URL/devices/register" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $USER1_TOKEN" \
  -d "{
    \"device_id\": \"$USER1_DEVICE_ID\",
    \"identity_public_key\": \"a1b2c3d4e5f67890123456789012345678901234567890123456789012345678\",
    \"identity_ed25519_verifying_key\": \"fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210\",
    \"signed_prekey\": {
      \"id\": 1,
      \"public_key\": \"f1e2d3c4b5a67890123456789012345678901234567890123456789012345678\",
      \"signature\": \"1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef\",
      \"timestamp\": $(date +%s)
    },
    \"prekeys\": [
      {
        \"id\": 1,
        \"public_key\": \"9876543210fedcba9876543210fedcba9876543210fedcba9876543210fedcba\"
      },
      {
        \"id\": 2,
        \"public_key\": \"abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890\"
      }
    ]
  }")
echo "$USER1_DEVICE" | jq '.'
if echo "$USER1_DEVICE" | jq -e '.error' > /dev/null 2>&1; then
  echo -e "${RED}Failed to register User 1 device${NC}"
  exit 1
fi
echo -e "${GREEN}User 1 Device ID: $USER1_DEVICE_ID${NC}"
echo ""

echo -e "${YELLOW}6. User 2 register device (with Ed25519 verifying key)...${NC}"
USER2_DEVICE_ID="${USER2_USER_ID}-macos"
USER2_DEVICE=$(curl -s -X POST "$BASE_URL/devices/register" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $USER2_TOKEN" \
  -d "{
    \"device_id\": \"$USER2_DEVICE_ID\",
    \"identity_public_key\": \"b1c2d3e4f5a67890123456789012345678901234567890123456789012345678\",
    \"identity_ed25519_verifying_key\": \"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\",
    \"signed_prekey\": {
      \"id\": 1,
      \"public_key\": \"e1f2a3b4c5d67890123456789012345678901234567890123456789012345678\",
      \"signature\": \"abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890\",
      \"timestamp\": $(date +%s)
    },
    \"prekeys\": [
      {
        \"id\": 1,
        \"public_key\": \"1111111111111111111111111111111111111111111111111111111111111111\"
      },
      {
        \"id\": 2,
        \"public_key\": \"2222222222222222222222222222222222222222222222222222222222222222\"
      }
    ]
  }")
echo "$USER2_DEVICE" | jq '.'
if echo "$USER2_DEVICE" | jq -e '.error' > /dev/null 2>&1; then
  echo -e "${RED}Failed to register User 2 device${NC}"
  exit 1
fi
echo -e "${GREEN}User 2 Device ID: $USER2_DEVICE_ID${NC}"
echo ""

echo -e "${YELLOW}7. User 1 send friend request to User 2...${NC}"
FRIEND_REQUEST=$(curl -s -X POST "$BASE_URL/friends/request" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $USER1_TOKEN" \
  -d "{
    \"username\": \"$USER2_USERNAME\"
  }")
echo "$FRIEND_REQUEST" | jq '.'
REQUEST_ID=$(echo "$FRIEND_REQUEST" | jq -r '.request_id // empty')
if [ -z "$REQUEST_ID" ]; then
  echo -e "${RED}Failed to send friend request${NC}"
  exit 1
fi
echo -e "${GREEN}Friend Request ID: $REQUEST_ID${NC}"
echo ""

echo -e "${YELLOW}8. User 2 get friend requests...${NC}"
USER2_REQUESTS=$(curl -s -X GET "$BASE_URL/friends/requests" \
  -H "Authorization: Bearer $USER2_TOKEN")
echo "$USER2_REQUESTS" | jq '.'
echo ""

echo -e "${YELLOW}9. User 2 accept friend request...${NC}"
ACCEPT_RESPONSE=$(curl -s -X POST "$BASE_URL/friends/accept" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $USER2_TOKEN" \
  -d "{
    \"request_id\": \"$REQUEST_ID\"
  }")
echo "$ACCEPT_RESPONSE" | jq '.'
echo ""

echo -e "${YELLOW}10. User 1 get friends list...${NC}"
USER1_FRIENDS=$(curl -s -X GET "$BASE_URL/friends/list" \
  -H "Authorization: Bearer $USER1_TOKEN")
echo "$USER1_FRIENDS" | jq '.'
echo ""

echo -e "${YELLOW}11. User 2 get friends list...${NC}"
USER2_FRIENDS=$(curl -s -X GET "$BASE_URL/friends/list" \
  -H "Authorization: Bearer $USER2_TOKEN")
echo "$USER2_FRIENDS" | jq '.'
echo ""

echo -e "${YELLOW}12. User 1 get User 2's prekey bundle by USER ID (NEW ENDPOINT)...${NC}"
USER2_BUNDLE_BY_USER=$(curl -s -X GET "$BASE_URL/users/$USER2_USER_ID/prekey-bundle" \
  -H "Authorization: Bearer $USER1_TOKEN")
echo "$USER2_BUNDLE_BY_USER" | jq '.'
if echo "$USER2_BUNDLE_BY_USER" | jq -e '.error' > /dev/null 2>&1; then
  echo -e "${RED}Failed to get prekey bundle by user ID${NC}"
else
  echo -e "${GREEN}✅ Successfully got prekey bundle by user ID${NC}"
fi
echo ""

echo -e "${YELLOW}13. User 2 get User 1's prekey bundle by USER ID (NEW ENDPOINT)...${NC}"
USER1_BUNDLE_BY_USER=$(curl -s -X GET "$BASE_URL/users/$USER1_USER_ID/prekey-bundle" \
  -H "Authorization: Bearer $USER2_TOKEN")
echo "$USER1_BUNDLE_BY_USER" | jq '.'
if echo "$USER1_BUNDLE_BY_USER" | jq -e '.error' > /dev/null 2>&1; then
  echo -e "${RED}Failed to get prekey bundle by user ID${NC}"
else
  echo -e "${GREEN}✅ Successfully got prekey bundle by user ID${NC}"
fi
echo ""

echo -e "${GREEN}=== Test Complete ===${NC}"
echo ""
echo "Summary:"
echo "  User 1 ID: $USER1_USER_ID"
echo "  User 2 ID: $USER2_USER_ID"
echo "  User 1 Device ID: $USER1_DEVICE_ID"
echo "  User 2 Device ID: $USER2_DEVICE_ID"
echo "  Friend Request ID: $REQUEST_ID"
