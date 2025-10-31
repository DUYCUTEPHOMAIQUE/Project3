# MVP Test Flow (Manual)

Quick steps to verify end-to-end flow for Key Agreement + Message Relay (ciphertext opaque).

## 1) Register Bob's device

POST http://localhost:3000/api/v1/devices/register

Body (example; use real keys):
```json
{
  "device_id": "bob-device-1",
  "identity_public_key": "<hex 64>",
  "signed_prekey": { "id": 1, "public_key": "<hex 64>", "signature": "<hex 128>", "timestamp": 1730340000 },
  "prekeys": [ { "id": 1, "public_key": "<hex 64>" }, { "id": 2, "public_key": "<hex 64>" } ]
}
```

## 2) Alice fetches Bob's prekey bundle

GET http://localhost:3000/api/v1/devices/bob-device-1/prekey-bundle

Response:
```json
{
  "identity_key": "<hex 64>",
  "signed_prekey": { "id": 1, "public_key": "<hex 64>", "signature": "<hex 128>", "timestamp": 1730340000 },
  "one_time_prekey": { "id": 1, "public_key": "<hex 64>" }
}
```

## 3) Alice performs X3DH locally (Rust core)
- Use `initiate()` to derive `shared_secret` and `ephemeral_key_pair`.
- Encrypt initial message (for MVP you can send opaque ciphertext string).

## 4) Send message to Bob (relay)

POST http://localhost:3000/api/v1/messages

Body:
```json
{
  "recipient_device_id": "bob-device-1",
  "sender_device_id": "alice-device-1",
  "message_type": "INITIAL",
  "ciphertext": "<opaque string>"
}
```

## 5) Bob polls messages

GET http://localhost:3000/api/v1/devices/bob-device-1/messages

Response:
```json
{
  "device_id": "bob-device-1",
  "messages": [
    { "id": "...", "ciphertext": "...", "timestamp": 1730340000, "sender_device_id": "alice-device-1", "message_type": "INITIAL", "recipient_device_id": "bob-device-1" }
  ]
}
```

Bob then uses `respond_full()` with `alice_identity_public` and `EK_pub` (from initial payload when wired up) to derive the same `shared_secret`, and decrypt locally.

> Note: In this MVP, server does not verify signatures nor decrypt content. Keys are opaque to server.
