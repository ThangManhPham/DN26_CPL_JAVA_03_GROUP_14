# M3 Sprint 1 Implementation and Handoff

## Phạm vi đã triển khai

| Task | Implementation | Kiểm chứng |
|---|---|---|
| S1-11 | Spring Boot, Swagger, Bearer scheme, request/response schemas, dev H2 | Context/dev smoke, OpenAPI, health |
| S1-12 | Register, email normalized/unique, BCrypt, Login, JWT HS256 | Persisted hash, duplicate/race, login đúng/sai, JWT thật |
| S1-13 | GET/PATCH profile từ JWT sub; sửa tên và avatar key; optimistic locking | Hai user độc lập; dữ liệu tồn tại qua login lại; partial PATCH/clear |
| S1-14 | DTO validation, strict JSON, exception mapping, security, request ID | 400/401/403/409/415/422; forged IDs; rollback request lỗi |
| S1-15 | Unit service/key config và integration controller/security/Flyway | Maven package chạy suite và đóng gói JAR |

Đây là trạng thái implementation local. PR review, CI và staging/integration với
PostgreSQL thật vẫn cần bằng chứng của nhóm trước khi đóng task theo Definition of Done.
Không bao gồm pairing, Flutter UI, Docker hay Couple Space/calendar của Sprint 2–3.

## Bằng chứng kiểm thử local ngày 16/10/2026

- `mvn package`: BUILD SUCCESS, 27 tests, 0 failures/errors.
- 17 integration cases cho API/security, 5 service unit cases, 3 signing-key unit cases,
  1 dev smoke và 1 context/migration test.
- `backend/scripts/smoke-auth.ps1`: PASS qua HTTP từ JAR đóng gói: health, register,
  duplicate email, login, GET profile, PATCH profile, missing/invalid token.
- Flyway thực sự áp dụng V1; Hibernate validate schema. Database kiểm thử là H2.
- Chưa chạy PostgreSQL thật, CI hay staging. Có thể chạy lại suite với DB test riêng
  theo TEST_DATABASE_* trong Backend README.

## Bàn giao M1 và M2

- Base path /api/v1. Xem OpenAPI tại /v3/api-docs hoặc Swagger /swagger-ui.html.
- Register: email/password/displayName → 201 user; không tự login.
- Login: email/password → 200 {accessToken, tokenType:"Bearer", user}.
- Gửi Authorization: Bearer <accessToken> cho GET/PATCH /users/me.
- Không gửi userId để chọn profile. JSON chỉ nhận field đúng contract.
- PATCH chỉ gửi field muốn đổi; avatarKey:null xóa metadata avatar.
- 401: xóa phiên local và yêu cầu login lại; chưa có refresh endpoint.
- H2 dev mất dữ liệu và key ephemeral đổi khi restart; dùng PostgreSQL và key cố định
  để test login lại qua nhiều lần restart.
- Upload avatar và kiểm tra storage object thuộc adapter media khi module đó sẵn sàng.
  Profile API hiện chỉ lưu key dưới namespace avatars/{current-user-uuid}/.

## Bàn giao M4

Để M3 chạy độc lập, repository đã bổ sung V1__create_users.sql, theo tên migration
trong kế hoạch database. V1 tạo users(id UUID, email normalized unique, password_hash,
display_name, avatar_key, created_at TIMESTAMP WITH TIME ZONE, version BIGINT).
Hibernate ddl-auto=validate; không dùng create/update ở dev hay test.

M4 dùng migration V2 trở lên cho couples/members/invites và FK tới users(id).
Không sửa migration đã áp dụng hoặc tự tạo users lần nữa. Nếu có migration khác
ở branch M4 chưa hiện trong checkout này, cần đối chiếu version/checksum khi tích hợp.

Authentication principal là org.springframework.security.oauth2.jwt.Jwt, sub là UUID user.
Ví dụ controller pairing lấy @AuthenticationPrincipal Jwt jwt rồi parse UUID.fromString(jwt.getSubject()).
Không nhận userId/coupleId từ client làm bằng chứng quyền sở hữu.
Pairing phải kiểm tra user và active membership trong service/transaction của M4.

## Bàn giao M5

- JDK 25; Maven package chạy test và đóng gói JAR.
- Không profile dev: PostgreSQL + JWT_SECRET Base64 >=32 random bytes bắt buộc.
- JWT_ISSUER mặc định ourspace; JWT_TTL_SECONDS mặc định 3600, giới hạn 60–86400.
- Flyway bật; migrations chạy trước JPA validate.
- Không log request body, Authorization header, token, password hoặc giá trị bind SQL.
- Health GET /actuator/health public, Swagger public; chỉ mở rộng endpoint public khi review.
- HTTPS và quản lý secret tại staging/prod do M5 cấu hình.
- Cùng integration suite có thể dùng TEST_DATABASE_URL/USERNAME/PASSWORD tới DB test riêng.
  Suite xóa users trước mỗi integration test; tuyệt đối không dùng DB chứa dữ liệu cần giữ.

## Quyết định auth của Sprint 1

Access JWT HS256, default TTL 1 giờ, không refresh/revoke server-side tại Sprint 1.
Client logout xóa token; người dùng login lại khi hết hạn. Server kiểm tra exp với
clock skew 0, issuer, nbf, iat và UUID subject. Dev không có secret sinh key tạm,
production thiếu/không đủ độ dài key thì từ chối khởi động.

Password tối thiểu 8 ký tự, tối đa 72 ký tự/72 UTF-8 bytes vì giới hạn BCrypt.
Không trim password; email strip/lowercase. Login sai email và sai mật khẩu trả cùng
INVALID_CREDENTIALS và message, đều thực hiện BCrypt check.

Bổ sung endpoint refresh hoặc chính sách revoke sau này cần thống nhất contract/session
trước khi thay đổi, không giả định token bị vô hiệu hóa ngay chỉ vì client logout.
