FROM golang:1.26.1-alpine AS builder
RUN apk add --no-cache git ca-certificates
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o /app/hardware-service .

FROM alpine:3.20
RUN apk add --no-cache ca-certificates wget
COPY --from=builder /app/hardware-service /hardware-service
EXPOSE 8082
ENTRYPOINT ["/hardware-service"]
