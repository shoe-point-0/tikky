# Stage 1: Build the application
FROM golang:1.24-alpine AS builder

WORKDIR /src

# Create a non-root user and group
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy Go module files and download dependencies to leverage Docker layer caching
COPY app/go.mod app/go.sum ./
RUN go mod download

# Copy the rest of the application source code
COPY app/ .

# Build the application into a static binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -ldflags '-w -s' -o /app/main .

# Stage 2: Create the final, minimal production image
FROM scratch

# Copy necessary files from the builder stage
# Copy SSL certificates for making potential HTTPS calls
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
# Copy user and group files for running as a non-root user
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group
# Copy the compiled application binary
COPY --from=builder /app/main /main

# Use the non-root user
USER appuser

# Expose the port the application runs on
EXPOSE 8080

# Define the command to run the application
CMD ["/main"]