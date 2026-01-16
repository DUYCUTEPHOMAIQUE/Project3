#!/bin/bash

BASE_URL="http://localhost:8080/api/v1"

echo "=== Testing Key Service API ==="
echo ""

echo "1. Register Alice user..."
ALICE_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "alice_user",
    "password": "SecurePass123",
    "email": "alice@example.com"
  }')
echo "$ALICE_RESPONSE" | jq '.'
ALICE_USER_ID=$(echo "$ALICE_RESPONSE" | jq -r '.user_id')
echo "Alice User ID: $ALICE_USER_ID"
echo ""

echo "2. Register Bob user..."
BOB_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "bob_user",
    "password": "SecurePass123",
    "email": "bob@example.com"
  }')
echo "$BOB_RESPONSE" | jq '.'
BOB_USER_ID=$(echo "$BOB_RESPONSE" | jq -r '.user_id')
echo "Bob User ID: $BOB_USER_ID"
echo ""

echo "3. Alice login..."
ALICE_LOGIN=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "alice_user",
    "password": "SecurePass123"
  }')
echo "$ALICE_LOGIN" | jq '.'
ALICE_TOKEN=$(echo "$ALICE_LOGIN" | jq -r '.access_token')
echo "Alice Token: ${ALICE_TOKEN:0:50}..."
echo ""

echo "4. Bob login..."
BOB_LOGIN=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "bob_user",
    "password": "SecurePass123"
  }')
echo "$BOB_LOGIN" | jq '.'
BOB_TOKEN=$(echo "$BOB_LOGIN" | jq -r '.access_token')
echo "Bob Token: ${BOB_TOKEN:0:50}..."
echo ""

echo "5. Alice register device..."
ALICE_DEVICE=$(curl -s -X POST "$BASE_URL/devices/register" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -d '{
    "device_id": "alice-device-1",
    "identity_public_key": "a1b2c3d4e5f6789012345678901234567890123456789012345678901234567890",
    "signed_prekey": {
      "id": 1,
      "public_key": "f1e2d3c4b5a6789012345678901234567890123456789012345678901234567890",
      "signature": "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
      "timestamp": 1730340000
    },
    "prekeys": [
      {
        "id": 1,
        "public_key": "9876543210fedcba9876543210fedcba9876543210fedcba9876543210fedcba"
      },
      {
        "id": 2,
        "public_key": "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
      }
    ]
  }')
echo "$ALICE_DEVICE" | jq '.'
echo ""

echo "6. Bob register device..."
BOB_DEVICE=$(curl -s -X POST "$BASE_URL/devices/register" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $BOB_TOKEN" \
  -d '{
    "device_id": "bob-device-1",
    "identity_public_key": "b1c2d3e4f5a6789012345678901234567890123456789012345678901234567890",
    "signed_prekey": {
      "id": 1,
      "public_key": "e1f2a3b4c5d6789012345678901234567890123456789012345678901234567890",
      "signature": "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
      "timestamp": 1730340000
    },
    "prekeys": [
      {
        "id": 1,
        "public_key": "1111111111111111111111111111111111111111111111111111111111111111"
      },
      {
        "id": 2,
        "public_key": "2222222222222222222222222222222222222222222222222222222222222222"
      }
    ]
  }')
echo "$BOB_DEVICE" | jq '.'
echo ""

echo "7. Alice get Bob prekey bundle..."
BOB_BUNDLE=$(curl -s -X GET "$BASE_URL/devices/bob-device-1/prekey-bundle" \
  -H "Authorization: Bearer $ALICE_TOKEN")
echo "$BOB_BUNDLE" | jq '.'
echo ""

echo "8. Bob get Alice prekey bundle..."
ALICE_BUNDLE=$(curl -s -X GET "$BASE_URL/devices/alice-device-1/prekey-bundle" \
  -H "Authorization: Bearer $BOB_TOKEN")
echo "$ALICE_BUNDLE" | jq '.'
echo ""

echo "=== Test Complete ==="
