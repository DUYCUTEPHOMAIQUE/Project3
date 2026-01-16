# Key Service

Key Exchange Service implemented in Go using Gin framework.

## Features

- User registration and authentication (JWT)
- Device registration with identity keys and prekeys
- Prekey bundle distribution for X3DH handshake
- In-memory storage (will migrate to PostgreSQL in Phase 3)

## Setup

```bash
go mod download
go run main.go
```

## Environment Variables

- `PORT`: Server port (default: 8080)
- `GIN_MODE`: Gin mode (debug/release, default: release)
- `JWT_SECRET`: JWT signing secret (required in production)

## API Endpoints

See `api.md` for complete API documentation.

## Run

```bash
go run main.go
```

## Build

```bash
go build -o key-service main.go
```
