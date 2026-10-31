# OURSPACE

**AI-POWERED COUPLE APP**  
**PROJECT SPECIFICATION & SPRINT DELIVERY PLAN**

**Version:** 1.0 · **Nhóm:** 5 thành viên · **Kế hoạch:** 3 sprints / 12 tuần (dự kiến)  
**Trạng thái:** Blueprint — chưa phải đặc tả được khóa hoặc sản phẩm đã triển khai  
**Ngày lập:** 16/10/2026

---

## 1. Executive Summary

OurSpace là ứng dụng mobile riêng tư dành cho hai người yêu nhau. Sản phẩm có chia sẻ ảnh tương tự Locket (bao gồm home-screen widget), timeline/reaction, Couple Space & lịch kỷ niệm, album chung, và AI hỗ trợ tạo câu chuyện kỷ niệm/lên kế hoạch hẹn hò.

**Giá trị khác biệt:** ảnh được chia sẻ theo những khoảnh khắc nhỏ hằng ngày, nhưng vẫn có thể được nhóm lại thành kỷ niệm có ý nghĩa và lên kế hoạch hẹn hò bằng AI. Sản phẩm không phải mạng xã hội công khai.

**Mục tiêu cuối kỳ:** 2 user có thể ghép đôi và sử dụng các luồng cốt lõi; backend và database khởi động qua Docker Compose; hệ thống có kiểm thử và demo; mỗi thành viên chứng minh được một feature end-to-end trong báo cáo.

| Thuộc tính | Định hướng |
|---|---|
| Nền tảng | Flutter mobile cho iOS; iOS WidgetKit cần kiểm chứng trên iPhone thật |
| Backend | Java Spring Boot modular monolith |
| Database | PostgreSQL + Flyway |
| Auth | Spring Security + JWT |
| Media | Private object storage (provider chưa chốt) |
| Push/Widget | Firebase Cloud Messaging/APNs + iOS WidgetKit (chưa triển khai) |
| AI | Hosted AI API gọi từ backend, không tự train model |
| Môi trường | Docker Compose, GitHub, GitHub Actions |

## 2. Scope & Requirements

### 2.1 Must-have

- Đăng ký/đăng nhập, bảo vệ password và profile.
- Sinh và nhập mã mời có hạn; một tài khoản chỉ thuộc một couple active.
- Upload/send ảnh chỉ trong couple; B thấy ảnh trong app; widget hiển thị theo khả năng refresh OS.
- Timeline riêng tư, photo detail, reaction và album.
- Love counter, ngày kỷ niệm, lịch chung và kế hoạch hẹn hò.
- AI Memory Story; AI Date Planner, cả hai có consent, draft và chỉnh sửa trước khi lưu.

### 2.2 Non-goals

Chưa xây chat realtime đầy đủ, video call, mạng xã hội công khai, payment, microservices, Kubernetes hay tự huấn luyện model AI. Các phần search nâng cao/notification phức tạp chỉ phát triển nếu còn thời gian.

### 2.3 Bảo mật và privacy

- Auth và ownership được kiểm tra server-side cho mọi ảnh/album/sự kiện/plan.
- Không cấp permanent public image URL; API secret không lưu trong Flutter/Git.
- Không gửi ảnh hoặc ghi chú sang AI nếu user chưa chọn và xác nhận.
- Unpairing/retention chưa chốt: phải được quyết định trước khi code luồng xóa.

## 3. Kiến trúc tổng thể

**Kiểu triển khai:** Flutter ↔ REST API Spring Boot ↔ PostgreSQL; ảnh lưu private object storage; backend gọi AI provider và push provider. Compose quản lý backend/DB trên máy dev; mobile/emulator chạy native ngoài Docker.

```text
Flutter App ─── REST/JWT ──> Spring Boot (modular monolith)
    │                              │
    ├── Native Home Widget         ├── PostgreSQL + Flyway
    │   (best-effort refresh)       ├── Private Object Storage
    └── Push Notification <────────├── FCM / push provider
                                   └── Hosted AI API
```

**Backend modules:** `identity`, `pairing`, `photo-sharing`, `timeline`, `couple-space`, `memory`, `date-planner`, plus `common/security`. Mỗi module expose interface rõ để tránh coupling.

**Nguyên tắc giao tiếp:** mọi endpoint private dùng Bearer token; resource queries luôn dựa trên couple membership của user; DTO JSON camelCase; timestamp ISO-8601/UTC; lỗi chuẩn gồm `code`, `message`, `details`, `requestId`.

## 4. Database Overview

| Entity | Chức năng | Những ràng buộc chính |
|---|---|---|
| `users` | Account/profile | email unique, password_hash |
| `couples` | Quan hệ cặp đôi | status, anniversary_date |
| `couple_members` | Thành viên cặp đôi | mỗi user chỉ có 1 active membership |
| `couple_invites` | Mã ghép đôi | code_hash, expiry, single-use |
| `photos` | Metadata ảnh | couple_id, sender_id, private storage_key |
| `photo_reactions` | Reaction | unique(photo_id,user_id) nếu một reaction |
| `albums`, `album_photos` | Album chung | photo và album cùng couple |
| `couple_events` | Lịch kỷ niệm | start timestamp/timezone |
| `date_plans` | Lịch hẹn | manual plan + AI draft |
| `ai_memory_stories` | Story AI | requested_by, content, draft status |

Để cấm một user có 2 couple active, dùng bảng `couple_members` và partial unique index trên `user_id WHERE left_at IS NULL`, đồng thời xử lý ghép đôi atomically trong transaction. Migration phải dùng Flyway và không sửa file đã được áp dụng.

## 5. API Contract (đề xuất)

| Method | Endpoint | Sprint / Owner |
|---|---|---|
| POST | `/api/v1/auth/register` | S1 / M3 |
| POST | `/api/v1/auth/login` | S1 / M3 |
| GET, PATCH | `/api/v1/users/me` | S1 / M3 |
| POST | `/api/v1/couple-invites` | S1 / M4 |
| POST | `/api/v1/couples/join` | S1 / M4 |
| GET, DELETE | `/api/v1/couples/me` | S1 / M4 |
| POST | `/api/v1/photos/upload-intents`, `/api/v1/photos` | S2 / M1 |
| GET | `/api/v1/photos/latest` | S2 / M1 |
| GET | `/api/v1/photos` (cursor), `/api/v1/photos/{id}` | S2 / M2 |
| PUT, DELETE | `/api/v1/photos/{id}/reaction` | S2 / M2 |
| GET, POST, PATCH | `/api/v1/events` và `/api/v1/events/{id}` | S2 / M3 |
| GET, POST | `/api/v1/albums` | S2 / M4 |
| POST, GET | `/api/v1/date-plans` | S2 / M5 |
| POST | `/api/v1/ai/memory-stories` | S3 / M4 |
| POST | `/api/v1/ai/date-plans` | S3 / M5 |

Contract v1 phải được chốt ngay Week 1. Flutter bắt đầu bằng mock API; chuyển sang API thật mà không đổi JSON shape tùy tiện.

## 6. Sprint Roadmap

| Sprint | Thời gian dự kiến | Mục tiêu | Demo cuối sprint |
|---|---|---|---|
| **1 — Foundation** | Week 1–4 | Dev env + authentication + pairing | A/B đăng ký, đăng nhập, ghép đôi, Couple Home |
| **2 — Features** | Week 5–8 | 5 feature owner end-to-end | Gửi ảnh/widget; timeline; calendar; album; date plan |
| **3 — AI & Release** | Week 9–12 | AI, reliability, test & staging | AI story, AI date suggestions, tổng demo, tài liệu |

**Cách chia công việc:** Sprint 1 theo chuyên môn để làm nền tảng. Sprint 2–3 theo feature owner để mỗi người có phần báo cáo riêng. Không ai phải chờ người khác hoàn thành toàn bộ module; mocks và API contract giúp làm song song.

## 7. Sprint 1 — Phân chia 25 task

| Member | Vai trò Sprint 1 | Công việc theo tuần |
|---|---|---|
| **M1** | Flutter UI/Auth | W1 Figma; W2 Login/Register UI + API; W3 Profile; W4 UI test |
| **M2** | Flutter Core/Pairing | W1 Flutter setup; W2 HTTP/token state; W3 Invite/Couple screens + API; W4 test 2 devices |
| **M3** | Backend Auth/Users | W1 Spring Boot/OpenAPI; W2 JWT/Register/Login; W3 Profile/validation; W4 tests |
| **M4** | Backend DB/Pairing | W1 ERD/Flyway; W2 Couple services; W3 Invite/Join/Unpair; W4 race/security tests |
| **M5** | DevOps/Integration | W1 GitHub/Docker; W2 CI; W3 README/smoke test; W4 staging/E2E |

### Danh sách issue chi tiết

| ID | Owner | Tuần | Đầu việc |
|---|---|---:|---|
| S1-01 | M1 | 1 | Figma Login/Register/Home/Profile |
| S1-02 | M1 | 2 | Login/Register UI & validation |
| S1-03 | M1 | 2 | Tích hợp Auth API |
| S1-04 | M1 | 3 | Profile UI & edit |
| S1-05 | M1 | 4 | UI tests & polish |
| S1-06 | M2 | 1 | Flutter setup, routing, folders |
| S1-07 | M2 | 2 | HTTP client, token storage, auth state |
| S1-08 | M2 | 3 | Create/Join Invite UI |
| S1-09 | M2 | 3 | Tích hợp Couple API, Couple Home |
| S1-10 | M2 | 4 | 2-device pairing tests |
| S1-11 | M3 | 1 | Spring Boot skeleton, OpenAPI |
| S1-12 | M3 | 2 | JWT + Register/Login |
| S1-13 | M3 | 3 | Profile APIs |
| S1-14 | M3 | 3 | Validation, exception, authorization |
| S1-15 | M3 | 4 | Auth tests |
| S1-16 | M4 | 1 | ERD + Flyway users/couples/invites |
| S1-17 | M4 | 2 | Couple entities/repository/services |
| S1-18 | M4 | 3 | Generate/Accept Invite APIs |
| S1-19 | M4 | 3 | Get Couple / Unpair APIs |
| S1-20 | M4 | 4 | Pairing & concurrency/security tests |
| S1-21 | M5 | 1 | Repo, branch protection, PR template |
| S1-22 | M5 | 1 | Docker Compose: backend + PostgreSQL |
| S1-23 | M5 | 2 | GitHub Actions build/test |
| S1-24 | M5 | 3 | Local runbook, .env.example, smoke test |
| S1-25 | M5 | 4 | Staging, end-to-end integration demo |

**Sprint 1 completion gate:** 2 accounts use real API; invite code cannot be reused/expired/misused; same user cannot be in two active couples; CI green; Docker documentation reproducible from clean checkout.

## 8. Feature Ownership trong Sprint 2 & 3

| Member | Feature ownership | Sprint 2 output | Sprint 3 output |
|---|---|---|---|
| **M1** | Photo Sharing & Widget | Capture/upload/send, latest photo, widget prototype | Retry, push, private media, device test |
| **M2** | Timeline & Reactions | Feed, detail, pagination, reactions | Filters nếu kịp, performance & permission tests |
| **M3** | Couple Space & Calendar | Love counter, anniversary, event CRUD | Reminder/timezone, acceptance tests |
| **M4** | Album & AI Memory Story | Album CRUD, add/remove photos | Consent, AI draft, edit/save story, fallback |
| **M5** | Date Planner & AI Recommendations | Manual plan create/edit/save | AI plans, schema validation, cost guardrails |

**Dependency rules:** M2/M4 dùng ảnh từ M1 theo `Photo` API; M3/M5 chia sẻ event/plan contract; M4/M5 tích hợp AI độc lập nhưng dùng chung AI client adapter. Owner chịu trách nhiệm full stack và báo cáo cho feature của mình, không có nghĩa là cấm giúp nhau code review.

## 9. Development Process

1. Week 1 kickoff: khóa repo layout, SDK versions, ERD v1, API error shape, key decisions.
2. Branch riêng gắn issue (`feature/S1-12-register-login`), PR về `develop`, review chéo.
3. CI chạy backend build/tests, Flutter analyze/tests và migration smoke tests.
4. Tích hợp trên `develop` ít nhất 2 lần/tuần; không để cuối Sprint mới ghép.
5. `main` là demo ổn định; secrets ở `.env` local và GitHub secrets, không commit.

**Definition of Done:** accepted user story; code merged qua reviewed PR; CI xanh; test & security check; docs/API/migration update; demo screenshot và bằng chứng đóng góp có dữ liệu giả.

## 10. Quality, AI & Release Criteria

### 10.1 Kiểm thử cốt lõi

- Login sai, token thiếu/expired; profile không lộ dữ liệu người khác.
- Invite hết hạn/dùng lại/tự ghép đôi; concurrency không cho user thuộc hai active couples.
- Photo private: user C không thể truy cập ảnh/album của A/B.
- Timeline pagination; upload retry; widget hoạt động theo OS best-effort.
- AI không consent thì không gọi model; timeout/schema invalid thì fallback.

### 10.2 Nguyên tắc AI

AI Story chỉ nhận ảnh/ghi chú do người dùng chọn. AI Date Planner chỉ gợi ý kế hoạch, không tự xác minh giờ mở cửa hay đặt dịch vụ. Kết quả là **draft** để người dùng xem/sửa/lưu. Backend lưu key và kiểm soát token/cost/rate limit.

### 10.3 Kết quả báo cáo cá nhân

Mỗi member chuẩn bị: use case, UI flow, data model, endpoints, Flutter+Backend implementation, tests, screenshots, PR/issue links, khó khăn và cách giải quyết. Phần Sprint 1 vẫn ghi công theo role gốc.

## 11. Rủi ro & Các quyết định cần chốt

| Chủ đề | Hành động |
|---|---|
| Widget iOS / cập nhật không realtime | Proof-of-concept trên iPhone thật; không hứa refresh tức thì |
| Storage media | Chọn private storage/short-lived URL; test permission |
| Unpairing và retention | Chốt policy giữ/xóa dữ liệu trước Sprint 1 Week 3 |
| JWT/session | Chốt token lifetime/refresh/revocation ở Week 1 |
| Flutter/JDK/Postgres versions | Pin chính xác trong project và CI |
| API contract drift | Chốt Week 1, dùng mocks/OpenAPI, review breaking changes |
| AI cost/privacy | Consent, minimal input, quota, timeout, fallback |
| Scope nhóm 5 người | Cắt P2 trước; ưu tiên pairing + sharing + private media |

**Các tài liệu kỹ thuật đầy đủ** (ERD Mermaid, API JSON examples, testing matrix, AI privacy flow, Sprint backlog và hướng dẫn Docker) nằm trong thư mục `docs/` của gói dự án.
