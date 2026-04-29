FROM golang:1.24-alpine AS builder
RUN apk add --no-cache git ca-certificates
WORKDIR /app

# Copy go.mod and go.sum
COPY services/hardware-service/go.mod ./
COPY services/hardware-service/go.sum* ./

# Download dependencies
RUN go mod download

# Copy the rest of the service
COPY services/hardware-service/ ./

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o /app/hardware-service .

FROM alpine:3.20
RUN apk add --no-cache ca-certificates wget
COPY --from=builder /app/hardware-service /hardware-service
EXPOSE 8082
ENTRYPOINT ["/hardware-service"]
