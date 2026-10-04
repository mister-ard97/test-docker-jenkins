FROM golang:1.27.1-alpine AS base
WORKDIR /src
COPY go.mod ./
COPY *.go ./

FROM base AS test
RUN go test -v ./...

FROM base AS build
ARG VERSION=dev
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath \
    -ldflags="-s -w -X main.version=${VERSION}" \
    -o /out/myapp .

FROM scratch
COPY --from=build /out/myapp /app/myapp
USER 65534:65534
EXPOSE 8080
ENTRYPOINT ["/app/myapp"]