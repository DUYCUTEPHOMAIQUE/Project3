# Nakama Integration trong Key Service

## Tổng quan

Key Service tự động tích hợp với Nakama để tạo user trong Nakama khi user đăng ký hoặc đăng nhập. Điều này đảm bảo mỗi user trong Key Service đều có tài khoản tương ứng trong Nakama.

## Luồng hoạt động

### Register Flow

1. User đăng ký với Key Service
2. Key Service tạo user trong database của mình
3. Key Service tự động gọi Nakama API để tạo user
4. Key Service lưu Nakama user ID và session token vào user record
5. Trả về response bao gồm cả Nakama info

### Login Flow

1. User đăng nhập với Key Service
2. Key Service validate credentials
3. Nếu user chưa có Nakama account, Key Service tự động tạo
4. Nếu user đã có Nakama account, Key Service refresh session
5. Trả về response bao gồm cả Nakama session token

## Cấu trúc Code

### NakamaClient Service

File: `internal/services/nakama_client.go`

- `AuthenticateCustom()`: Authenticate với Nakama bằng custom token (JWT từ Key Service)
- `GetAccount()`: Lấy thông tin account từ Nakama

### User Model Updates

File: `internal/models/user.go`

- Thêm field `NakamaUserID`: Lưu Nakama user ID
- Thêm field `NakamaSession`: Lưu Nakama session token

### Response Models Updates

- `UserRegistrationResponse`: Thêm `nakama_user_id` và `nakama_session`
- `LoginResponse`: Thêm `nakama_user_id` và `nakama_session`

## Configuration

### Environment Variables

Key Service sử dụng các environment variables sau để kết nối với Nakama:

- `NAKAMA_HOST`: Nakama server host (default: `127.0.0.1`)
- `NAKAMA_PORT`: Nakama server port (default: `7350`)
- `NAKAMA_SERVER_KEY`: Nakama server key (default: `defaultkey`)

### Docker Compose

Trong `docker-compose.yml`, key-service được config với:

```yaml
environment:
  - NAKAMA_HOST=nakama
  - NAKAMA_PORT=7350
  - NAKAMA_SERVER_KEY=defaultkey
depends_on:
  nakama:
    condition: service_healthy
```

## Error Handling

- Nếu Nakama không available khi register/login, Key Service vẫn thành công
- Nakama info sẽ là `null` trong response nếu Nakama integration failed
- User có thể retry login sau để get Nakama session

## API Response Examples

### Register Response

```json
{
  "user_id": "uuid-string",
  "username": "alice",
  "email": "alice@example.com",
  "nakama_user_id": "nakama-uuid",
  "nakama_session": "nakama-session-token",
  "created_at": 1730340000
}
```

### Login Response

```json
{
  "access_token": "jwt-token",
  "refresh_token": "refresh-token",
  "token_type": "Bearer",
  "expires_in": 86400,
  "user": {
    "user_id": "uuid-string",
    "username": "alice",
    "email": "alice@example.com"
  },
  "nakama_user_id": "nakama-uuid",
  "nakama_session": "nakama-session-token"
}
```

## Testing

1. Start services: `docker-compose up -d`
2. Register user mới
3. Verify Nakama user được tạo
4. Login với user đó
5. Verify Nakama session được refresh

## Notes

- Nakama user được tạo với custom authentication
- Custom ID là JWT token từ Key Service
- Username được sync từ Key Service
- Nakama session token được lưu trong Key Service user record để reuse
