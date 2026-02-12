FROM swift:5.9-jammy AS builder

WORKDIR /build
COPY Package.* ./
RUN swift package resolve
COPY Sources ./Sources
COPY Tests ./Tests
RUN swift build -c release --static-swift-stdlib

FROM ubuntu:22.04

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates tzdata \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /build/.build/release/Run /app/Run
COPY Resources /app/Resources

ENV PORT=8080
EXPOSE 8080

CMD ["./Run", "serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
