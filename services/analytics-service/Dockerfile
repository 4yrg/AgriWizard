FROM golang:1.26.1-alpine AS builder
RUN apk add --no-cache git ca-certificates
WORKDIR /app

# Copy go.mod first for better layer caching
COPY go.mod ./

# Copy go.sum if it exists (optional)
COPY go.sum* ./

# Download dependencies
RUN go mod download

# Copy the rest of the application
COPY . .

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o /app/analytics-service .

FROM alpine:3.20
RUN apk add --no-cache ca-certificates wget
COPY --from=builder /app/analytics-service /analytics-service
EXPOSE 8083
ENTRYPOINT ["/analytics-service"]
