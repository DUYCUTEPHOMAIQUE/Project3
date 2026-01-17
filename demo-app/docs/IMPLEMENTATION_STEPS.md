# Implementation Steps - Nakama Integration

## Bước 1: Install Dependencies

```bash
cd demo-app
flutter pub add nakama
flutter pub add flutter_secure_storage  # Optional nhưng recommended
flutter pub add jwt_decoder  # Optional, để parse JWT
flutter pub get
```

## Bước 2: Update NakamaService

1. Uncomment code trong `lib/services/nakama_service.dart`
2. Import Nakama package
3. Implement các methods đã được outline

## Bước 3: Update Key Service Port

Đảm bảo `KeyServiceClient` đang dùng đúng port 8099 (đã được set trong code).

## Bước 4: Implement Nakama Hook (Server-side)

Tạo file `nakama-server/data/modules/before_authenticate_custom.lua`:

```lua
local function before_authenticate_custom(context, payload)
  -- Extract token từ payload
  local token = payload.token or payload.id
  
  -- Verify token với Key Service
  -- TODO: Implement HTTP call tới Key Service để verify token
  -- local http = require("http")
  -- local response = http.request("http://key-service:8099/api/v1/auth/verify", {
  --   headers = { Authorization = "Bearer " .. token }
  -- })
  
  -- Extract user info từ token hoặc response
  -- local user_id = extract_user_id_from_token(token)
  -- local username = extract_username_from_token(token)
  
  -- Return user info để Nakama tạo/link user
  return {
    user_id = user_id,
    username = username,
  }
end
```

## Bước 5: Update UI Components

1. Update `lib/main.dart` - `AuthWrapper` để dùng `AuthService`
2. Update `lib/views/login_page.dart` - Dùng `AuthService` thay vì `ApiService`
3. Update `lib/views/register_page.dart` - Dùng `AuthService`

## Bước 6: Test Flow

1. Test Register flow:
   - Register user mới
   - Verify tokens được lưu
   - Verify Nakama session được tạo

2. Test Login flow:
   - Login với user đã có
   - Verify tokens được refresh
   - Verify Nakama session được restore

3. Test Logout flow:
   - Logout user
   - Verify tokens được clear
   - Verify Nakama session được disconnect

## Bước 7: Error Handling

1. Handle Key Service unavailable
2. Handle Nakama unavailable
3. Handle token expiry
4. Handle network errors

## Bước 8: Security Hardening

1. Migrate từ `shared_preferences` sang `flutter_secure_storage` cho tokens
2. Implement token refresh logic
3. Add rate limiting cho auth requests
4. Add logging và monitoring

## Checklist

- [ ] Install Nakama package
- [ ] Implement NakamaService đầy đủ
- [ ] Implement Nakama hook trên server
- [ ] Update UI để dùng AuthService
- [ ] Test register flow
- [ ] Test login flow
- [ ] Test logout flow
- [ ] Test error cases
- [ ] Migrate to secure storage
- [ ] Add token refresh logic
