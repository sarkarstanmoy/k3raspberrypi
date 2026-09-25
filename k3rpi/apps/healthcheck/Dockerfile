# Stage 1: compile the Go binary.
# This stage has the whole Go toolchain (~800MB) but gets thrown away.
FROM golang:1.27-alpine AS build

WORKDIR /src

# Copy the dependency list first. Docker caches this step, so dependencies
# are only re-downloaded when go.mod/go.sum actually change.
COPY go.mod go.sum ./
RUN go mod download

# Now the source code.
COPY . .

# CGO_ENABLED=0 makes a self-contained binary with no C libraries,
# so it runs on the tiny alpine image below.
RUN CGO_ENABLED=0 go build -o /healthcheck .

# Stage 2: the image that actually ships. Starts empty and only gets the binary.
FROM alpine:3.24

# Run as a normal user instead of root.
RUN adduser -D -u 10001 app
USER app

COPY --from=build /healthcheck /usr/local/bin/healthcheck

# Documents the port from main.go: ListenAndServe(":3000")
EXPOSE 3000

CMD ["healthcheck"]
