FROM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /out/archeic ./cmd/archeic

FROM gcr.io/distroless/static-debian12
WORKDIR /app
COPY --from=build /out/archeic /app/archeic
COPY --from=build /src/migrations /app/migrations
EXPOSE 8080
ENTRYPOINT ["/app/archeic"]
CMD ["server"]
