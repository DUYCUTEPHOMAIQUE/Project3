# Nakama Integration Architecture & Implementation Plan

## Tổng quan kiến trúc

### Authentication Flow Architecture

```
┌─────────────┐
│  Demo App   │
│  (Flutter)  │
└──────┬──────┘
       │
       ├─────────────────┐
       │                 │
       ▼                 ▼
┌─────────────┐   ┌─────────────┐
│ Key Service │   │   Nakama   │
│  (Port 8099)│   │ (Port 7350)│
└─────────────┘   └─────────────┘
       │                 │
       │                 │
       └─────────────────┘
         Custom Auth
```

### Luồng đăng ký/đăng nhập đề xuất

#### 1. **Register Flow**

```
User → Demo App
  ↓
Demo App → Key Service POST /api/v1/auth/register
  ↓ (username, password, email)
Key Service → Validate & Create User
  ↓ (return: user_id, username, JWT access_token)
Demo App → Save JWT token
  ↓
Demo App → Nakama authenticateCustom(token=JWT)
  ↓
Nakama Hook → Verify JWT với Key Service
  ↓ (extract user_id, username)
Nakama → Create/Link User
  ↓ (return: Nakama session token)
Demo App → Save Nakama session
  ↓
✅ User authenticated với cả Key Service & Nakama
```

#### 2. **Login Flow**

```
User → Demo App
  ↓
Demo App → Key Service POST /api/v1/auth/login
  ↓ (username, password)
Key Service → Validate credentials
  ↓ (return: JWT access_token)
Demo App → Save JWT token
  ↓
Demo App → Nakama authenticateCustom(token=JWT)
  ↓
Nakama Hook → Verify JWT với Key Service
  ↓ (extract user_id, username)
Nakama → Get existing user or create
  ↓ (return: Nakama session token)
Demo App → Save Nakama session
  ↓
✅ User authenticated với cả Key Service & Nakama
```

## Kiến trúc code đề xuất

### 1. Service Layer Structure

```
lib/
├── services/
│   ├── auth_service.dart          # Unified auth service (Key Service + Nakama)
│   ├── nakama_service.dart        # Nakama client wrapper
│   ├── key_service_client.dart    # Key Service API client (refactor từ api_service.dart)
│   └── session_manager.dart       # Quản lý session (JWT + Nakama session)
```

### 2. Models

```
lib/
├── models/
│   ├── auth/
│   │   ├── user.dart              # User model
│   │   ├── auth_result.dart       # Auth result với tokens
│   │   └── session.dart          # Session info
```

### 3. Implementation Strategy

#### Phase 1: Setup Nakama Client
- Add `nakama` package vào `pubspec.yaml`
- Tạo `NakamaService` class
- Configure Nakama client với server address

#### Phase 2: Unified Auth Service
- Tạo `AuthService` để orchestrate cả Key Service và Nakama
- Refactor `ApiService` thành `KeyServiceClient` (chỉ gọi Key Service API)
- Tạo `SessionManager` để quản lý cả JWT và Nakama session

#### Phase 3: Update UI Flow
- Update `LoginPage` và `RegisterPage` để dùng `AuthService`
- Update `AuthWrapper` để check cả Key Service và Nakama session
- Handle token refresh và re-authentication

## Chi tiết implementation

### NakamaService Responsibilities

1. **Connection Management**
   - Connect/disconnect từ Nakama server
   - Handle reconnection logic
   - Manage socket connection

2. **Authentication**
   - `authenticateCustom(token)` - Authenticate với custom token từ Key Service
   - `authenticateDevice(deviceId)` - Device authentication (optional)
   - `authenticateEmail(email, password)` - Direct email auth (nếu cần)

3. **Session Management**
   - Get current session
   - Check session validity
   - Refresh session nếu cần

4. **Realtime Features** (sau này)
   - Socket events
   - Channel management
   - RPC calls

### AuthService Responsibilities

1. **Register**
   - Call Key Service register endpoint
   - Save JWT token
   - Authenticate với Nakama bằng custom token
   - Save Nakama session
   - Return unified auth result

2. **Login**
   - Call Key Service login endpoint
   - Save JWT token
   - Authenticate với Nakama bằng custom token
   - Save Nakama session
   - Return unified auth result

3. **Logout**
   - Clear Key Service token
   - Disconnect Nakama
   - Clear Nakama session
   - Clear all stored data

4. **Check Auth Status**
   - Check JWT token validity
   - Check Nakama session validity
   - Return combined auth status

### SessionManager Responsibilities

1. **Token Storage**
   - Store JWT access token (Key Service)
   - Store Nakama session token
   - Store refresh tokens nếu có

2. **Token Retrieval**
   - Get JWT token
   - Get Nakama session
   - Get user info

3. **Token Validation**
   - Check JWT expiry
   - Check Nakama session expiry
   - Auto-refresh nếu cần

## Security Considerations

1. **Token Storage**
   - Sử dụng `flutter_secure_storage` thay vì `shared_preferences` cho sensitive data
   - Encrypt tokens khi lưu trữ

2. **Token Transmission**
   - Luôn dùng HTTPS cho production
   - Không log tokens trong production

3. **Custom Auth Hook**
   - Nakama hook phải verify JWT với Key Service
   - Sử dụng shared secret hoặc public key để verify
   - Rate limiting cho auth requests

4. **Session Management**
   - Set appropriate token expiry
   - Implement refresh token flow
   - Handle concurrent sessions

## Nakama Hook Implementation (Server-side)

Cần implement Nakama hook để verify custom token:

```lua
-- nakama-server/data/modules/before_authenticate_custom.lua
local function before_authenticate_custom(context, payload)
  -- Extract token from payload
  local token = payload.token
  
  -- Verify token với Key Service
  -- Call Key Service API để verify token
  -- Extract user_id và username từ token hoặc Key Service response
  
  -- Return user info để Nakama tạo/link user
  return {
    user_id = user_id,
    username = username,
    -- other metadata
  }
end
```

## Migration Strategy

1. **Step 1**: Add Nakama package, create NakamaService (không dùng ngay)
2. **Step 2**: Create AuthService, refactor existing code để dùng AuthService
3. **Step 3**: Implement Nakama authentication trong AuthService
4. **Step 4**: Update UI để handle cả Key Service và Nakama
5. **Step 5**: Test end-to-end flow
6. **Step 6**: Implement Nakama hook trên server

## Dependencies cần thêm

```yaml
dependencies:
  nakama: ^3.0.0  # Nakama Flutter client
  flutter_secure_storage: ^9.0.0  # Secure token storage
  jwt_decoder: ^2.0.0  # JWT token parsing (optional)
```

## Testing Strategy

1. **Unit Tests**
   - Test AuthService methods
   - Test NakamaService methods
   - Test SessionManager

2. **Integration Tests**
   - Test full register flow
   - Test full login flow
   - Test token refresh
   - Test reconnection

3. **E2E Tests**
   - Test user can register và login
   - Test user can use Nakama features sau khi auth
   - Test session persistence
