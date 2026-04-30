FROM golang:1.24-alpine AS builder
RUN apk add --no-cache git ca-certificates
WORKDIR /app

# Copy go.mod and go.sum
COPY services/analytics-service/go.mod ./
COPY services/analytics-service/go.sum* ./

# Download dependencies
RUN go mod download

# Copy the rest of the service
COPY services/analytics-service/ ./

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o /app/analytics-service .

FROM alpine:3.20
RUN apk add --no-cache ca-certificates wget
COPY --from=builder /app/analytics-service /analytics-service
EXPOSE 8088
ENTRYPOINT ["/analytics-service"]
