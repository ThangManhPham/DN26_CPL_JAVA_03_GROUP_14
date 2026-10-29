# OurSpace local Docker environment

This setup runs the Spring Boot backend and PostgreSQL for local development. Flutter and its emulator run on the host.

## Start

1. Copy .env.example to .env and replace DB_PASSWORD with a local-only value.
2. From the repository root, run docker compose up --build -d.
3. Check startup with docker compose ps and docker compose logs -f backend.
4. Open http://localhost:8080/actuator/health or http://localhost:8080/swagger-ui.html.

The backend waits for PostgreSQL to report healthy. Flyway applies migrations at application startup, while Hibernate validates the schema. The development Spring profile is active by default; it still connects to PostgreSQL through the explicit datasource variables.

## Stop and keep local data

Run docker compose down. The named pgdata volume remains and preserves the local database. docker compose down -v deletes that volume and all local database data.

## Ports and credentials

The API and database ports bind to 127.0.0.1 only. Change APP_PORT or DB_PORT in .env if those host ports are already in use. The example password is for local development only. Do not commit .env, production credentials, JWT secrets, or real user data.

If JWT_SECRET is blank, the dev profile generates a temporary signing key when the backend starts, so tokens stop working after a backend restart. Staging or production must use a fixed secret from a secret manager and must not use the dev profile.

## Image build

The backend image uses a Maven/JDK 25 build stage and a smaller JRE 25 runtime stage. Maven packages the JAR during image build, and the runtime process runs as a non-root user. The runtime image includes curl for the actuator healthcheck.
