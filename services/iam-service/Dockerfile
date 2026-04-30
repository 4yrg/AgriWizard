# ---- Build Stage ----
FROM golang:1.24-alpine AS builder

RUN apk add --no-cache git ca-certificates

WORKDIR /app

# Copy go.mod and go.sum
COPY services/iam-service/go.mod ./
COPY services/iam-service/go.sum* ./

# Download dependencies
RUN go mod download

# Copy the rest of the service
COPY services/iam-service/ ./

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o /app/iam-service .

# ---- Runtime Stage ----
FROM alpine:3.20

RUN apk add --no-cache ca-certificates wget

COPY --from=builder /app/iam-service /iam-service

EXPOSE 8086

ENTRYPOINT ["/iam-service"]
