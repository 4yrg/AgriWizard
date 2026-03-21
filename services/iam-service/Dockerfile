# ---- Build Stage ----
FROM golang:1.26.1-alpine AS builder

RUN apk add --no-cache git ca-certificates

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o /app/iam-service .

# ---- Runtime Stage ----
FROM alpine:3.20

RUN apk add --no-cache ca-certificates wget

COPY --from=builder /app/iam-service /iam-service

EXPOSE 8081

ENTRYPOINT ["/iam-service"]
