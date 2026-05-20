# Build stage
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Copy go.mod first
COPY go.mod ./

# Copy source code
COPY . .

# Download dependencies (generates go.sum if needed)
RUN go mod tidy

# Build the binary with optimizations
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s" \
    -o /websocket-server .

# Runtime stage
FROM alpine:3.19

# Security: run as non-root user
RUN addgroup -g 1000 appgroup && \
    adduser -u 1000 -G appgroup -D appuser

WORKDIR /app

# Copy binary and static files
COPY --from=builder /websocket-server .
COPY --from=builder /app/static ./static

# Set ownership
RUN chown -R appuser:appgroup /app

USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Run the server
ENTRYPOINT ["./websocket-server"]
