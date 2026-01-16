# Key Exchange Service API Documentation

## Overview

Key Exchange Service là backend service chịu trách nhiệm quản lý device registration và phân phối prekey bundles cho X3DH key agreement protocol. Service này chỉ xử lý public keys và không bao giờ lưu trữ private keys.

**Base URL**: `http://localhost:8080` (configurable via `PORT` environment variable)

**API Version**: `v1`

**Content-Type**: `application/json`

---

## Authentication

Service sử dụng JWT (JSON Web Token) cho authentication. Sau khi đăng nhập thành công, client sẽ nhận được access token và refresh token. Access token phải được gửi trong header `Authorization` cho các protected endpoints.

**Token Format**: `Bearer <access_token>`

**Token Expiration**:
- Access Token: 24 hours
- Refresh Token: 7 days

---

## Endpoints

### 1. Register User Account

Đăng ký một user account mới.

**Endpoint**: `POST /api/v1/auth/register`

**Authentication**: Not required

**Request Headers**:
```
Content-Type: application/json
```

**Request Body**:
```json
{
  "username": "string (required, 3-50 chars, alphanumeric + underscore)",
  "password": "string (required, min 8 chars)",
  "email": "string (optional, valid email format)"
}
```

**Field Descriptions**:
- `username`: Unique username (3-50 characters, alphanumeric và underscore only)
- `password`: Password (minimum 8 characters, should contain letters and numbers)
- `email`: Optional email address (valid email format)

**Request Example**:
```json
{
  "username": "alice_user",
  "password": "SecurePass123",
  "email": "alice@example.com"
}
```

**Success Response** (201 Created):
```json
{
  "user_id": "uuid-string",
  "username": "alice_user",
  "email": "alice@example.com",
  "created_at": 1730340000
}
```

**Error Responses**:

- **400 Bad Request**: Invalid request body
```json
{
  "error": "username is required and must be 3-50 characters"
}
```

- **400 Bad Request**: Invalid password
```json
{
  "error": "password must be at least 8 characters"
}
```

- **400 Bad Request**: Invalid email format
```json
{
  "error": "email must be a valid email address"
}
```

- **409 Conflict**: Username already exists
```json
{
  "error": "Username already exists"
}
```

**Validation Rules**:
- `username`: Required, 3-50 characters, alphanumeric và underscore only, unique
- `password`: Required, minimum 8 characters, should contain at least one letter and one number
- `email`: Optional, must be valid email format if provided

---

### 2. Login

Đăng nhập và nhận JWT access token và refresh token.

**Endpoint**: `POST /api/v1/auth/login`

**Authentication**: Not required

**Request Headers**:
```
Content-Type: application/json
```

**Request Body**:
```json
{
  "username": "string (required)",
  "password": "string (required)"
}
```

**Request Example**:
```json
{
  "username": "alice_user",
  "password": "SecurePass123"
}
```

**Success Response** (200 OK):
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 86400,
  "user": {
    "user_id": "uuid-string",
    "username": "alice_user",
    "email": "alice@example.com"
  }
}
```

**Response Field Descriptions**:
- `access_token`: JWT access token (expires in 24 hours)
- `refresh_token`: JWT refresh token (expires in 7 days)
- `token_type`: Token type, always "Bearer"
- `expires_in`: Access token expiration time in seconds (86400 = 24 hours)
- `user`: User information object

**Error Responses**:

- **400 Bad Request**: Missing credentials
```json
{
  "error": "username and password are required"
}
```

- **401 Unauthorized**: Invalid credentials
```json
{
  "error": "Invalid username or password"
}
```

---

### 3. Refresh Token

Refresh access token bằng refresh token.

**Endpoint**: `POST /api/v1/auth/refresh`

**Authentication**: Not required (but requires refresh token)

**Request Headers**:
```
Content-Type: application/json
```

**Request Body**:
```json
{
  "refresh_token": "string (required)"
}
```

**Request Example**:
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Success Response** (200 OK):
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 86400
}
```

**Error Responses**:

- **400 Bad Request**: Missing refresh token
```json
{
  "error": "refresh_token is required"
}
```

- **401 Unauthorized**: Invalid or expired refresh token
```json
{
  "error": "Invalid or expired refresh token"
}
```

---

### 4. Register Device

Đăng ký một device mới với identity key và prekeys.

**Endpoint**: `POST /api/v1/devices/register`

**Authentication**: Required (Bearer token)

**Request Headers**:
```
Content-Type: application/json
Authorization: Bearer <access_token>
```

**Request Body**:
```json
{
  "device_id": "string (required)",
  "user_id": "string (optional)",
  "identity_public_key": "string (required, hex-encoded, 64 chars)",
  "signed_prekey": {
    "id": "number (required)",
    "public_key": "string (required, hex-encoded, 64 chars)",
    "signature": "string (required, hex-encoded, 128 chars)",
    "timestamp": "number (required, Unix timestamp)"
  },
  "prekeys": [
    {
      "id": "number (required)",
      "public_key": "string (required, hex-encoded, 64 chars)"
    }
  ]
}
```

**Field Descriptions**:
- `device_id`: Unique identifier cho device (ví dụ: "bob-device-1", "alice-phone-2024")
- `user_id`: Optional user identifier để group multiple devices của cùng một user
- `identity_public_key`: X25519 identity public key (32 bytes) được encode thành hex string (64 characters)
- `signed_prekey`: Signed prekey được ký bởi identity key
  - `id`: Unique identifier cho signed prekey
  - `public_key`: X25519 signed prekey public key (32 bytes) hex-encoded
  - `signature`: Ed25519 signature của signed prekey public key (64 bytes) hex-encoded
  - `timestamp`: Unix timestamp khi signed prekey được tạo
- `prekeys`: Array của one-time prekeys (ít nhất 1 prekey)
  - `id`: Unique identifier cho one-time prekey
  - `public_key`: X25519 one-time prekey public key (32 bytes) hex-encoded

**Request Example**:
```json
{
  "device_id": "bob-device-1",
  "user_id": "bob-user-123",
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
}
```

**Success Response** (201 Created):
```json
{
  "device_id": "bob-device-1",
  "registration_token": "string (hex-encoded, 64 chars)",
  "timestamp": 1730340000
}
```

**Error Responses**:

- **400 Bad Request**: Invalid request body
```json
{
  "error": "device_id is required and must be a string"
}
```

- **400 Bad Request**: Invalid hex format
```json
{
  "error": "identity_public_key must be a valid hex string (64 characters)"
}
```

- **400 Bad Request**: Missing required fields
```json
{
  "error": "prekeys is required and must be an array"
}
```

- **400 Bad Request**: Empty prekeys array
```json
{
  "error": "prekeys must contain at least one prekey"
}
```

- **401 Unauthorized**: Missing or invalid token
```json
{
  "error": "Unauthorized"
}
```

- **409 Conflict**: Device already registered
```json
{
  "error": "Device already registered"
}
```

**Validation Rules**:
- `device_id`: Required, non-empty string
- `identity_public_key`: Required, exactly 64 hex characters (32 bytes)
- `signed_prekey.id`: Required, number
- `signed_prekey.public_key`: Required, exactly 64 hex characters (32 bytes)
- `signed_prekey.signature`: Required, exactly 128 hex characters (64 bytes)
- `signed_prekey.timestamp`: Required, positive number
- `prekeys`: Required, array with at least 1 element
- Each prekey in `prekeys`: Must have `id` (number) and `public_key` (64 hex chars)

---

### 5. Get Prekey Bundle

Lấy prekey bundle của một device để initiate X3DH handshake. One-time prekey sẽ được consume (xóa) sau khi trả về.

**Endpoint**: `GET /api/v1/devices/:device_id/prekey-bundle`

**Authentication**: Required (Bearer token)

**Request Headers**:
```
Authorization: Bearer <access_token>
```

**URL Parameters**:
- `device_id` (path parameter): Device ID của device cần lấy prekey bundle

**Request Example**:
```
GET /api/v1/devices/bob-device-1/prekey-bundle
```

**Success Response** (200 OK):
```json
{
  "identity_key": "a1b2c3d4e5f6789012345678901234567890123456789012345678901234567890",
  "identity_ed25519_verifying_key": "fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210",
  "signed_prekey": {
    "id": 1,
    "public_key": "f1e2d3c4b5a6789012345678901234567890123456789012345678901234567890",
    "signature": "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
    "timestamp": 1730340000
  },
  "one_time_prekey": {
    "id": 1,
    "public_key": "9876543210fedcba9876543210fedcba9876543210fedcba9876543210fedcba"
  }
}
```

**Response Field Descriptions**:
- `identity_key`: X25519 identity public key (hex-encoded, 64 chars)
- `identity_ed25519_verifying_key`: Ed25519 verifying key để verify signature của signed prekey (hex-encoded, 64 chars)
- `signed_prekey`: Signed prekey object
  - `id`: Signed prekey ID
  - `public_key`: X25519 signed prekey public key (hex-encoded, 64 chars)
  - `signature`: Ed25519 signature (hex-encoded, 128 chars)
  - `timestamp`: Unix timestamp khi signed prekey được tạo
- `one_time_prekey`: Optional one-time prekey (sẽ bị consume sau khi trả về)
  - `id`: One-time prekey ID
  - `public_key`: X25519 one-time prekey public key (hex-encoded, 64 chars)

**Note**: `one_time_prekey` có thể không có trong response nếu device không còn one-time prekeys available. Trong trường hợp này, X3DH handshake vẫn có thể thực hiện được nhưng sẽ không có DH4 component.

**Error Responses**:

- **400 Bad Request**: Missing device_id
```json
{
  "error": "device_id is required"
}
```

- **401 Unauthorized**: Missing or invalid token
```json
{
  "error": "Unauthorized"
}
```

- **404 Not Found**: Device not found
```json
{
  "error": "Device not found"
}
```

**Behavior**:
- One-time prekey sẽ được lấy từ pool và xóa khỏi storage sau khi trả về
- Nếu device không còn one-time prekeys, response sẽ không có `one_time_prekey` field
- Signed prekey sẽ luôn được trả về (không bị consume)

---

## Authentication Middleware

Tất cả protected endpoints yêu cầu authentication token trong header `Authorization`:

```
Authorization: Bearer <access_token>
```

**Middleware Behavior**:
1. Extract token từ `Authorization` header
2. Validate token signature và expiration
3. Extract user information từ token claims
4. Attach user context vào request
5. Continue to handler nếu valid, return 401 nếu invalid

**JWT Token Claims**:
```json
{
  "user_id": "uuid-string",
  "username": "alice_user",
  "exp": 1730426400,
  "iat": 1730340000,
  "type": "access"
}
```

**Error Response khi token invalid**:
```json
{
  "error": "Unauthorized",
  "message": "Invalid or expired token"
}
```

**Protected Endpoints**:
- `POST /api/v1/devices/register` - Requires authentication
- `GET /api/v1/devices/:device_id/prekey-bundle` - Requires authentication
- Tất cả endpoints trong `/api/v1/devices/*` (trừ public endpoints)

**Public Endpoints**:
- `POST /api/v1/auth/register` - No authentication required
- `POST /api/v1/auth/login` - No authentication required
- `POST /api/v1/auth/refresh` - No authentication required (but requires refresh token)

---

## Data Models

### User Registration Request

```typescript
interface UserRegistrationRequest {
  username: string; // 3-50 chars, alphanumeric + underscore
  password: string; // min 8 chars
  email?: string; // valid email format
}
```

### User Registration Response

```typescript
interface UserRegistrationResponse {
  user_id: string; // UUID
  username: string;
  email?: string;
  created_at: number; // Unix timestamp
}
```

### Login Request

```typescript
interface LoginRequest {
  username: string;
  password: string;
}
```

### Login Response

```typescript
interface LoginResponse {
  access_token: string; // JWT token
  refresh_token: string; // JWT refresh token
  token_type: string; // "Bearer"
  expires_in: number; // seconds (86400 = 24 hours)
  user: {
    user_id: string; // UUID
    username: string;
    email?: string;
  };
}
```

### Refresh Token Request

```typescript
interface RefreshTokenRequest {
  refresh_token: string; // JWT refresh token
}
```

### Refresh Token Response

```typescript
interface RefreshTokenResponse {
  access_token: string; // New JWT access token
  token_type: string; // "Bearer"
  expires_in: number; // seconds (86400 = 24 hours)
}
```

### Device Registration Request

```typescript
interface DeviceRegistrationRequest {
  device_id: string;
  user_id?: string;
  identity_public_key: string; // hex-encoded, 64 chars
  signed_prekey: {
    id: number;
    public_key: string; // hex-encoded, 64 chars
    signature: string; // hex-encoded, 128 chars
    timestamp: number; // Unix timestamp
  };
  prekeys: Array<{
    id: number;
    public_key: string; // hex-encoded, 64 chars
  }>;
}
```

### Device Registration Response

```typescript
interface DeviceRegistrationResponse {
  device_id: string;
  registration_token: string; // hex-encoded, 64 chars
  timestamp: number; // Unix timestamp
}
```

### Prekey Bundle Response

```typescript
interface PreKeyBundleResponse {
  identity_key: string; // hex-encoded, 64 chars
  identity_ed25519_verifying_key: string; // hex-encoded, 64 chars
  signed_prekey: {
    id: number;
    public_key: string; // hex-encoded, 64 chars
    signature: string; // hex-encoded, 128 chars
    timestamp: number; // Unix timestamp
  };
  one_time_prekey?: {
    id: number;
    public_key: string; // hex-encoded, 64 chars
  };
}
```

---

## Error Handling

Tất cả error responses đều có format:

```json
{
  "error": "Error message description"
}
```

**HTTP Status Codes**:
- `200 OK`: Request thành công
- `201 Created`: Resource được tạo thành công
- `400 Bad Request`: Invalid request (validation errors, malformed data)
- `401 Unauthorized`: Authentication required hoặc invalid token
- `404 Not Found`: Resource không tồn tại
- `409 Conflict`: Resource đã tồn tại (username/device already exists)
- `500 Internal Server Error`: Server error

---

## Security Considerations

1. **Private Keys**: Service không bao giờ nhận hoặc lưu trữ private keys. Chỉ public keys được lưu trữ.

2. **Signature Verification**: Client nên verify signature của signed prekey trước khi sử dụng trong X3DH handshake.

3. **One-time Prekeys**: One-time prekeys được consume sau khi sử dụng để đảm bảo forward secrecy.

4. **Password Security**: Passwords được hash bằng bcrypt với salt rounds >= 10. Plaintext passwords không bao giờ được lưu trữ.

5. **JWT Security**:
   - Access tokens có expiration time (24 hours)
   - Refresh tokens có expiration time (7 days)
   - Tokens được ký bằng secret key (stored in environment variable)
   - Tokens không chứa sensitive information

6. **HTTPS**: Service nên chỉ chạy trên HTTPS trong production để protect tokens và credentials.

7. **CORS**: Service nên configure CORS để chỉ cho phép requests từ authorized origins.

8. **Rate Limiting**: Nên implement rate limiting cho authentication endpoints để prevent brute force attacks.

---

## Usage Flow

### Example: Alice initiates chat với Bob

1. **Alice registers user account**:
```bash
POST /api/v1/auth/register
{
  "username": "alice_user",
  "password": "SecurePass123",
  "email": "alice@example.com"
}
```

2. **Alice logs in**:
```bash
POST /api/v1/auth/login
{
  "username": "alice_user",
  "password": "SecurePass123"
}
```
Response includes `access_token` và `refresh_token`.

3. **Alice registers device** (with authentication):
```bash
POST /api/v1/devices/register
Authorization: Bearer <alice_access_token>
{
  "device_id": "alice-device-1",
  "identity_public_key": "...",
  "signed_prekey": {...},
  "prekeys": [...]
}
```

4. **Bob registers user account và device** (tương tự steps 1-3)

5. **Alice fetches Bob's prekey bundle** (with authentication):
```bash
GET /api/v1/devices/bob-device-1/prekey-bundle
Authorization: Bearer <alice_access_token>
```

6. **Alice performs X3DH locally** (using Rust core):
   - Use prekey bundle để initiate X3DH handshake
   - Derive shared secret
   - Create Double Ratchet session

7. **Alice sends encrypted message** (via Nakama, not this service):
   - Encrypt message using Double Ratchet
   - Send encrypted ciphertext through Nakama channel

---

## Implementation Notes

- Service sử dụng in-memory storage (sẽ migrate sang PostgreSQL trong Phase 3)

- User data structure:
  ```go
  type User struct {
    UserID    string    // UUID
    Username  string    // Unique, 3-50 chars
    Email     *string   // Optional
    PasswordHash string // bcrypt hashed password
    CreatedAt int64     // Unix timestamp
  }
  ```

- Device data structure:
  ```go
  type DeviceInfo struct {
    DeviceID          string
    UserID            string // Required, linked to User
    IdentityPublicKey string
    SignedPrekey      SignedPreKey
    OneTimePrekeys    map[uint32]string // Map<prekey_id, public_key>
    RegisteredAt      int64
  }
  ```

- JWT Token Structure:
  ```go
  type Claims struct {
    UserID   string `json:"user_id"`
    Username string `json:"username"`
    Type     string `json:"type"` // "access" or "refresh"
    jwt.StandardClaims
  }
  ```

- Authentication Middleware:
  - Extract token từ `Authorization` header
  - Validate token signature và expiration
  - Attach user context (`user_id`, `username`) vào Gin context
  - Handler có thể access user info: `c.Get("user_id")`, `c.Get("username")`

- Password Hashing:
  - Sử dụng bcrypt với cost factor >= 10
  - Generate salt tự động
  - Compare password với hash khi login

- One-time prekeys được lưu trong map và consume khi được fetch
- Signed prekey không bị consume và có thể được fetch nhiều lần
- Device registration yêu cầu user đã authenticated (user_id từ token)

---

## Future Enhancements

1. **Prekey Replenishment**: API để device upload thêm one-time prekeys khi pool sắp hết
2. **Device Revocation**: API để revoke device và invalidate prekeys
3. **Prekey Rotation**: API để rotate signed prekey
4. **Rate Limiting**: Thêm rate limiting cho authentication endpoints để prevent brute force
5. **Password Reset**: API để reset password qua email
6. **Email Verification**: Verify email address khi đăng ký
7. **Two-Factor Authentication**: Thêm 2FA support
8. **Session Management**: API để list và revoke active sessions
9. **Database Migration**: Migrate từ in-memory sang PostgreSQL với proper indexing
10. **Token Blacklist**: Implement token blacklist cho logout functionality
