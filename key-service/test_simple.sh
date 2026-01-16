#!/bin/bash

BASE_URL="http://localhost:8080/api/v1"

echo "=== Key Service API Test ==="
echo ""

echo "1. Register Alice..."
curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"Pass1234","email":"alice@test.com"}' | jq '.'
echo ""

echo "2. Register Bob..."
curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"username":"bob","password":"Pass1234","email":"bob@test.com"}' | jq '.'
echo ""

echo "3. Alice login..."
ALICE_TOKEN=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"Pass1234"}' | jq -r '.access_token')
echo "Token: ${ALICE_TOKEN:0:50}..."
echo ""

echo "4. Bob login..."
BOB_TOKEN=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"bob","password":"Pass1234"}' | jq -r '.access_token')
echo "Token: ${BOB_TOKEN:0:50}..."
echo ""

echo "5. Alice register device..."
curl -s -X POST "$BASE_URL/devices/register" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -d '{
    "device_id":"alice-device",
    "identity_public_key":"a1b2c3d4e5f67890123456789012345678901234567890123456789012345678",
    "signed_prekey":{"id":1,"public_key":"f1e2d3c4b5a67890123456789012345678901234567890123456789012345678","signature":"1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef","timestamp":1730340000},
    "prekeys":[{"id":1,"public_key":"1111111111111111111111111111111111111111111111111111111111111111"}]
  }' | jq '.'
echo ""

echo "6. Bob register device..."
curl -s -X POST "$BASE_URL/devices/register" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $BOB_TOKEN" \
  -d '{
    "device_id":"bob-device",
    "identity_public_key":"b1c2d3e4f5a67890123456789012345678901234567890123456789012345678",
    "signed_prekey":{"id":1,"public_key":"e1f2a3b4c5d67890123456789012345678901234567890123456789012345678","signature":"abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890","timestamp":1730340000},
    "prekeys":[{"id":1,"public_key":"2222222222222222222222222222222222222222222222222222222222222222"}]
  }' | jq '.'
echo ""

echo "7. Alice get Bob prekey bundle..."
curl -s -X GET "$BASE_URL/devices/bob-device/prekey-bundle" \
  -H "Authorization: Bearer $ALICE_TOKEN" | jq '.'
echo ""

echo "8. Bob get Alice prekey bundle..."
curl -s -X GET "$BASE_URL/devices/alice-device/prekey-bundle" \
  -H "Authorization: Bearer $BOB_TOKEN" | jq '.'
echo ""

echo "=== Test Complete ==="
