# 07. Local Development, Docker & Configuration

## 7.1 Nguyên tắc

- **Docker Compose** đồng bộ **Spring Boot/backend dependencies + PostgreSQL**, không cần chạy Flutter emulator trong Docker.
- Mỗi thành viên có database local riêng cùng cấu trúc được Flyway quản lý.
- Có hai chế độ: (A) full backend trong container; (B) DB Docker + Spring Boot chạy IntelliJ để debug.
- `docker compose up -d --build` chỉ chạy sau khi đã có `backend/Dockerfile`, `pom.xml`/wrapper và source backend thực tế.

## 7.2 Cấu trúc repo đề xuất

```text
ourspace/
├── backend/
│   ├── src/main/java/...
│   ├── src/main/resources/db/migration/
│   ├── Dockerfile
│   └── pom.xml
├── mobile/
│   ├── lib/
│   ├── android/
│   ├── ios/
│   └── pubspec.yaml
├── docs/
├── .github/workflows/
├── compose.yaml
├── .env.example
├── .gitignore
└── README.md
```

## 7.3 Compose mẫu để triển khai khi code sẵn sàng

```yaml
services:
  db:
    image: postgres:17-alpine  # pin exact version/digest khi chốt
    environment:
      POSTGRES_DB: ourspace
      POSTGRES_USER: ourspace
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    ports:
      - "127.0.0.1:5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ourspace -d ourspace"]
      interval: 5s
      timeout: 3s
      retries: 12
    volumes:
      - pgdata:/var/lib/postgresql/data

  backend:
    build: ./backend
    ports:
      - "8080:8080"
    environment:
      SPRING_DATASOURCE_URL: jdbc:postgresql://db:5432/ourspace
      SPRING_DATASOURCE_USERNAME: ourspace
      SPRING_DATASOURCE_PASSWORD: ${DB_PASSWORD}
    depends_on:
      db:
        condition: service_healthy

volumes:
  pgdata:
```

`backend/Dockerfile` cần build ứng dụng và Java runtime phù hợp với JDK đã khóa. Không tự ý copy mẫu trên vào repository rồi nghĩ đã chạy được nếu backend chưa có source/Dockerfile.

## 7.4 Cấu hình `.env.example`

```dotenv
# COPY to .env and replace local values. Never commit .env.
DB_PASSWORD=change-me-local-only
SPRING_PROFILES_ACTIVE=dev
# AI_API_KEY=   # not needed in Sprint 1
```

Không commit `.env`, file key/service-account hoặc token. M5 thiết lập secrets cho GitHub Actions qua kho secrets của repository.

## 7.5 Lệnh local

```bash
cp .env.example .env
# Sửa DB_PASSWORD theo máy của mình.
docker compose up -d --build
docker compose ps
docker compose logs -f backend
```

Chế độ debug backend trong IDE: `docker compose up -d db`, đặt datasource host `localhost:5432`; cấu hình này **khác** hostname `db` dùng bên trong Docker network. Với Flutter Android emulator, `localhost` của emulator không phải localhost máy host; API base URL phải cấu hình tương ứng thiết bị/emulator.

**Không chạy** `docker compose down -v` nếu muốn giữ dữ liệu local, vì `-v` xóa DB volume.

## 7.6 Version và môi trường

M5 phải viết một bảng version thật sau kickoff: Java/JDK, Spring Boot, Flutter/Dart, PostgreSQL image, Docker Compose và OS đã test. Pin version trong build files/CI thay vì chỉ ghi text ở README.

## 7.7 Troubleshooting quick checks

1. DB không healthy: kiểm tra `.env`, volume và `docker compose logs db`.
2. Backend connect fail: xem datasource host `db` khi chạy container; `localhost` khi chạy IDE.
3. Flyway fail: migration version trùng, migration đã merge bị sửa, hoặc schema drift.
4. Flutter API fail: kiểm tra thiết bị, base URL, firewall và HTTPS/network security config.
5. Cổng 5432/8080 bận: chỉnh port host, giữ internal container port ổn định.
