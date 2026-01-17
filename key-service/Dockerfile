# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o key-service .

# Final stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates curl netcat-openbsd

WORKDIR /root/

# Copy the binary from builder
COPY --from=builder /app/key-service .

# Expose port
EXPOSE 8099

# Set environment variable for port
ENV PORT=8099

# Run the binary
CMD ["./key-service"]
