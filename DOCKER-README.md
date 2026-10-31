# OurSpace local Docker environment

This setup runs the Spring Boot backend, PostgreSQL and a private S3-compatible SeaweedFS bucket for local development. Flutter and its emulator run on the host.

## Start

1. Copy .env.example to .env and replace DB_PASSWORD and MINIO_ROOT_PASSWORD with local-only values.
2. From the repository root, run docker compose up --build -d.
3. Check startup with docker compose ps and docker compose logs -f backend.
4. Open http://localhost:8080/actuator/health or http://localhost:8080/swagger-ui.html. The S3 endpoint is http://localhost:9000 (local only).

The backend waits for PostgreSQL and starts alongside the object store, which creates the private bucket on startup. Flyway applies the PostgreSQL migrations (V1–V4 plus the repeatable push-token table migration) at startup, while Hibernate validates the schema. The development Spring profile is active by default; Compose explicitly selects PostgreSQL migrations rather than the H2 fallback.

## Stop and keep local data

Run docker compose down. The named pgdata and objectdata volumes remain and preserve the local database and photos. docker compose down -v deletes both volumes and all local data.

## Ports and credentials

The API, database and object-store ports bind to 127.0.0.1 only. Change APP_PORT or DB_PORT in .env if those host ports are already in use. The example credentials are for local development only. Do not commit .env, production credentials, JWT secrets, or real user data. The photo bucket is not public; the backend checks couple membership before serving bytes.

Firebase push is off by default. Once a private Firebase service-account JSON is available, set `FIREBASE_SERVICE_ACCOUNT_FILE` to its absolute path and `FIREBASE_HOST_UID` to `id -u` in your local `.env`, then run `docker compose -f compose.yaml -f compose.firebase.yaml up -d --build`. The overlay mounts the key read-only inside the backend; never commit it. This sends generic photo alerts only after the partner has registered a device while logged in. iOS also needs APNs setup and a physical iPhone.

If JWT_SECRET is blank, the dev profile generates a temporary signing key when the backend starts, so tokens stop working after a backend restart. Staging or production must use a fixed secret from a secret manager and must not use the dev profile.

## Image build

The backend image uses a Maven/JDK 25 build stage and a smaller JRE 25 runtime stage. Maven packages the JAR during image build, and the runtime process runs as a non-root user. The runtime image includes curl for the actuator healthcheck.
