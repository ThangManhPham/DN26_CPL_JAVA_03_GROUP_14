# OurSpace Backend

Backend Sprint 1 của M3 đã triển khai Register/Login với JWT, GET/PATCH profile,
validation và bộ test unit/integration. Các API trả dữ liệu thật từ database.

## Công nghệ

Java 25 (đã kiểm tra Oracle JDK 25.0.1), Maven 3.9.15, Spring Boot 3.5.6,
Springdoc 2.8.5. Spring Security Resource Server/Nimbus xử lý JWT;
BCrypt strength 12 hash mật khẩu. Dependency versions do Spring Boot quản lý.

## Chạy local ngay bằng H2

Mở PowerShell tại thư mục `backend/`, dùng JDK 25:

```powershell
mvn package
mvn spring-boot:run '-Dspring-boot.run.profiles=dev'
```

Hoặc chạy JAR đã đóng gói:

```powershell
java -jar target/ourspace-backend-0.1.0-SNAPSHOT.jar --spring.profiles.active=dev
```

Truy cập Swagger: http://localhost:8080/swagger-ui.html
Health: http://localhost:8080/actuator/health
OpenAPI: http://localhost:8080/v3/api-docs

Flyway tạo bảng `users`; Hibernate chỉ validate schema, không tạo/sửa bảng.
H2 in-memory mất dữ liệu khi dừng JVM. Nếu dev không đặt JWT_SECRET, ứng dụng
sinh signing key ngẫu nhiên mỗi lần khởi động; token cũ hết hiệu lực khi restart.
Các biến SPRING_DATASOURCE_* đã có trong môi trường sẽ ghi đè H2 fallback.
Dừng server bằng Ctrl+C.

## Demo Register → Login → Profile

Trong một terminal khác:

```powershell
$apiBase = 'http://localhost:8080/api/v1'
$registerBody = @{ email = 'alex@example.com'; password = 'ExamplePassword123!'; displayName = 'Alex' } | ConvertTo-Json
$profile = Invoke-RestMethod -Method Post -Uri "$apiBase/auth/register" -ContentType 'application/json' -Body $registerBody

$loginBody = @{ email = 'alex@example.com'; password = 'ExamplePassword123!' } | ConvertTo-Json
$session = Invoke-RestMethod -Method Post -Uri "$apiBase/auth/login" -ContentType 'application/json' -Body $loginBody
$authHeaders = @{ Authorization = "Bearer $($session.accessToken)" }

Invoke-RestMethod -Uri "$apiBase/users/me" -Headers $authHeaders
Invoke-RestMethod -Method Patch -Uri "$apiBase/users/me" -Headers $authHeaders -ContentType 'application/json' -Body '{"displayName":"Alex Updated"}'
```

Trong Swagger, Register trả user (201); Login trả accessToken/tokenType/user (200).
Copy accessToken vào Authorize để gọi GET/PATCH profile.
Không lưu token/mật khẩu thật vào log, screenshot, issue hoặc báo cáo.

## Contract và policy

| Endpoint | Kết quả |
|---|---|
| POST /api/v1/auth/register | 201 + user; email trùng 409 EMAIL_ALREADY_EXISTS |
| POST /api/v1/auth/login | 200 + tokenType Bearer, accessToken, user; sai thông tin 401 INVALID_CREDENTIALS |
| GET /api/v1/users/me | 200 + hồ sơ của UUID trong JWT sub |
| PATCH /api/v1/users/me | 200 + hồ sơ đã lưu; chỉ nhận displayName/avatarKey |

- Email strip và lowercase; database unique và CHECK normalized bảo vệ cả request đồng thời.
- Mật khẩu 8–72 ký tự và tối đa 72 UTF-8 bytes, không trim. Login không thay đổi password.
- Tên hiển thị không rỗng, tối đa 100 ký tự; trim trước khi lưu.
- JWT HS256, issuer mặc định ourspace, TTL mặc định 3600 giây; kiểm tra signature,
  issuer, exp, nbf, iat và sub UUID. Không chấp nhận thuật toán khác.
- Chưa có refresh/revocation server-side: hết hạn thì login lại; client logout bằng
  cách xóa token. Token đã cấp còn hợp lệ tới expiry nếu signing key không đổi.
- PATCH bỏ qua trường không gửi; displayName:null bị từ chối; avatarKey:null xóa avatar.
- Avatar key tối đa 512 ký tự, dạng avatars/{UUID-của-mình}/file.png (chữ/số, slash,
  underscore, hyphen; một extension), không nhận URL, traversal hoặc namespace user khác.
  Đây là lưu metadata, không upload file hoặc cấp quyền đọc object. Storage adapter sau này
  phải kiểm tra object tồn tại và ownership trước khi ký URL.
- Trường ngoài contract (id/userId/email/passwordHash...) bị từ chối 400 INVALID_REQUEST.
- JSON hỏng/thiếu body: 400; validation: 422; thiếu/sai/hết hạn token: 401; thiếu quyền: 403;
  sai content type: 415; conflict cập nhật đồng thời: 409 PROFILE_CONFLICT.
- Error JSON gồm code/message/details/requestId; header X-Request-Id khớp requestId.
  JWT và password hash không xuất hiện trong profile/response lỗi.

## PostgreSQL và signing key cố định

Cần database PostgreSQL riêng do M5 cung cấp; mặc định chạy không profile dev sẽ
yêu cầu PostgreSQL và signing key hợp lệ. Đặt biến môi trường tại backend/:

```powershell
$env:SPRING_DATASOURCE_URL = 'jdbc:postgresql://localhost:5432/ourspace'
$env:SPRING_DATASOURCE_USERNAME = 'ourspace'
$env:SPRING_DATASOURCE_PASSWORD = '<mat-khau-db-local>'
$keyBytes = New-Object byte[] 32
[System.Security.Cryptography.RandomNumberGenerator]::Fill($keyBytes)
$env:JWT_SECRET = [Convert]::ToBase64String($keyBytes)
mvn spring-boot:run
```

Lệnh sinh key trên dùng PowerShell 7/.NET hỗ trợ RandomNumberGenerator.Fill.
Trong Windows PowerShell 5.1, dùng:

```powershell
$keyBytes = New-Object byte[] 32
$keyGenerator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try { $keyGenerator.GetBytes($keyBytes) } finally { $keyGenerator.Dispose() }
$env:JWT_SECRET = [Convert]::ToBase64String($keyBytes)
```

JWT_SECRET là Base64 của ít nhất 32 random bytes; production lưu key cố định trong
secret manager, không tạo key mới mỗi lần restart. JWT_TTL_SECONDS cho phép 60–86400,
JWT_ISSUER mặc định ourspace. File .env.example chỉ là mẫu; Spring Boot/Maven không tự
nạp .env. CLI cần đặt biến trực tiếp; IDE/Compose phải cấu hình nạp rõ ràng.

## Kiểm thử và tích hợp

`mvn package` chạy unit/integration tests rồi tạo executable JAR.
Kết quả local 16/10/2026: **27 tests pass, 0 failures/errors**, JAR build thành công.
HTTP smoke từ JAR cũng pass: health, register, email trùng, login, GET/PATCH profile,
token thiếu/sai. Có thể chạy lại smoke trên Windows từ backend/:

```powershell
./scripts/smoke-auth.ps1
```

Script khởi động server tạm chỉ trên loopback, dùng H2 riêng, tự chọn port và tự dừng
tiến trình trong finally. Không in token hoặc password; log ở target/http-smoke*.log.

Integration tests dùng JWT thật, Flyway thật và schema validation trên H2 PostgreSQL mode.
Bao gồm auth/profile, validation, email trùng/race, token giả/hết hạn, ownership,
PATCH rollback, 401/403 và OpenAPI.

Có thể chạy cùng suite với PostgreSQL test database **riêng, dùng dữ liệu giả**:

```powershell
$env:TEST_DATABASE_URL = 'jdbc:postgresql://localhost:5432/ourspace_test'
$env:TEST_DATABASE_USERNAME = 'ourspace'
$env:TEST_DATABASE_PASSWORD = '<mat-khau-db-test>'
mvn test
```

Suite xóa toàn bộ users trong database test trước từng integration test.
Không trỏ TEST_DATABASE_URL vào database dev chứa dữ liệu cần giữ hoặc production.
PostgreSQL thực tế và CI/staging do M4/M5 phối hợp kiểm chứng.

M4 tiếp tục migrations V2 trở lên; không tạo lại bảng users hoặc sửa V1 đã áp dụng.
Contract cho M1/M2 và hướng dẫn cho M4 xem `../docs/13-m3-sprint1-delivery.md`.
