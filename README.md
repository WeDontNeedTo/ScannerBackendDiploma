# Diploma Backend (Vapor)

Swift Server bootstrap using Vapor + Fluent + PostgreSQL with Xcode and Docker setup.

## Requirements
- Swift 5.9+
- Xcode 15+ (for IDE)
- Docker (optional)

## Local run
```bash
swift build
swift run Run migrate
swift run Run serve
```

Open http://localhost:8080/ to see the health check.

## Xcode
Open `Package.swift` in Xcode. The IDE will resolve dependencies and let you run the `Run` target.

## Docker
```bash
docker compose up --build
```

The API will be available at http://localhost:8080/ and uses a Postgres container.

## Sample API
```bash
curl -X POST http://localhost:8080/todos -H 'Content-Type: application/json' -d '{"title":"First"}'
curl http://localhost:8080/todos
```
