FROM golang:1.24-alpine AS builder
RUN apk add --no-cache git ca-certificates
WORKDIR /app

# Copy go.mod and go.sum from the service directory
COPY services/notification-service/go.mod ./
COPY services/notification-service/go.sum* ./

# Download dependencies
RUN go mod download

# Copy the rest of the service
COPY services/notification-service/ ./

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o /app/notification-service .

FROM alpine:3.20
RUN apk add --no-cache ca-certificates wget
COPY --from=builder /app/notification-service /notification-service
EXPOSE 8091
ENTRYPOINT ["/notification-service"]
