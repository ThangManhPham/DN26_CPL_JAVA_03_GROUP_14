# 06. Sprint Plan, Task Assignment & Ownership

## 6.1 Quy ước dự án

- Team: **5 người**; 3 Sprint × 4 tuần là **giả định lập kế hoạch**.
- Sprint 1 chia theo **role để dựng nền tảng**; Sprint 2–3 mỗi người **làm owner một vertical feature** (Flutter → Spring Boot → database/migration → tests → docs).
- Parallel-first: frontend mock API theo contract; backend code theo contract; integration định kỳ, không chờ nhau hoàn thành cả module.
- Sprint goals ưu tiên trước; task nào có thể cắt được ghi vào risk/plan.

## 6.2 Sprint 1 — Foundation & Couple Connection

Trạng thái implementation local của M3 (S1-11–15) và các phụ thuộc bàn giao được ghi tại [M3 Sprint 1](13-m3-sprint1-delivery.md). Definition of Done vẫn yêu cầu PR/review/CI và bằng chứng demo.

**Goal:** 2 tài khoản đăng ký, đăng nhập, chỉnh sửa profile, ghép đôi với nhau và nhìn thấy Couple Home; backend/database chạy cùng môi trường Docker; PR/test workflow hoạt động.

| Task ID | Tuần | Owner | Task | Dependency / đầu ra |
|---|---:|---|---|---|
| S1-01 | 1 | M1 | Figma Login, Register, Home, Profile | Design tokens, flow screen |
| S1-02 | 2 | M1 | Login/Register UI + validation | Figma |
| S1-03 | 2 | M1 | Tích hợp Login/Register API, loading/errors | Auth contract; có thể mock |
| S1-04 | 3 | M1 | Profile screen + edit | Profile contract; có thể mock |
| S1-05 | 4 | M1 | UI tests, accessibility & polish | Screens hoàn chỉnh |
| S1-06 | 1 | M2 | Khởi tạo Flutter app, routing, folders | Chốt app/package name |
| S1-07 | 2 | M2 | HTTP client, secure token storage, auth state | Contract + shared auth design |
| S1-08 | 3 | M2 | UI tạo/nhập invite code | Contract pairing; mock |
| S1-09 | 3 | M2 | Tích hợp Couple API + Couple Home | S1-18 contract/API |
| S1-10 | 4 | M2 | Test pairing trên 2 thiết bị / emulator | Backend pairing ready |
| S1-11 | 1 | M3 | Setup Spring Boot, packages, OpenAPI | Repo/tool versions |
| S1-12 | 2 | M3 | Register/Login + JWT Spring Security | User migration |
| S1-13 | 3 | M3 | GET/PATCH profile APIs | Auth ready |
| S1-14 | 3 | M3 | Validation, exception mapping, authorization | Security conventions |
| S1-15 | 4 | M3 | Auth unit/integration tests | S1-12–14 |
| S1-16 | 1 | M4 | ERD và Flyway migrations cho users/couples/invites | Kickoff data contract |
| S1-17 | 2 | M4 | Entity/Repository/Service: couple & invite | S1-16; có thể dùng mock principal |
| S1-18 | 3 | M4 | Generate/Accept invite APIs | Security contract + DB transaction |
| S1-19 | 3 | M4 | Get Couple / Unpair APIs | Chốt retention policy |
| S1-20 | 4 | M4 | Pairing test: expired, used, race, owner check | S1-18–19 |
| S1-21 | 1 | M5 | GitHub repo, branch rules, PR template | Cả nhóm cùng chốt |
| S1-22 | 1 | M5 | Dockerfile + Compose Spring Boot/PostgreSQL | S1-11/16 cần skeleton, healthcheck |
| S1-23 | 2 | M5 | CI backend build/test; Flutter analyze/test | Backend/mobile skeleton |
| S1-24 | 3 | M5 | README, .env.example, runbook, smoke tests | Dev env hoạt động |
| S1-25 | 4 | M5 | Staging/demo + E2E tích hợp | Các module đã merge |

### Sprint 1 milestone theo tuần

| Tuần | Sản phẩm demo / checkpoint |
|---|---|
| Week 1 | Clone repo, chạy được DB/backend skeleton, Flutter skeleton; ERD + API v1 đã thống nhất |
| Week 2 | Login/Register chạy được qua API thật; CI cơ bản xanh |
| Week 3 | Hai tài khoản ghép đôi, xem nhau trên Couple Home |
| Week 4 | E2E tests, lỗi mã mời, demo 2 thiết bị, README chạy từ máy mới |

### Blockers và cách xử lý

| Dependency | Cách tránh chờ đợi |
|---|---|
| Flutter Auth đợi M3 | M1/M2 dùng mock đúng JSON contract |
| M4 pairing đợi auth M3 | Fake/test principal qua abstraction, chuyển JWT khi ready |
| M5 Docker đợi backend | Dựng Compose với healthcheck trước, hoàn thiện Dockerfile khi có skeleton |
| UI cần schema DB | FE chỉ cần API contract, không phụ thuộc trực tiếp bảng |
| Migration conflict | M4 quản lý lịch migration Sprint 1; các Sprint sau thống nhất người tạo version |

## 6.3 Sprint 2 — 5 Feature Owners

| Member | Feature (chịu trách nhiệm end-to-end) | Scope hoàn thành để demo |
|---|---|---|
| **M1** | **Photo Sharing & Widget** | Camera/gallery, upload private ảnh, gửi tới couple, recent photo API, widget proof + notification cơ bản |
| **M2** | **Timeline & Reactions** | Timeline pagination, photo detail, reaction API/UI, authorization, lỗi loading/empty |
| **M3** | **Couple Space & Shared Calendar** | Love counter, anniversary, CRUD sự kiện couple, trang lịch chung |
| **M4** | **Memory Albums** | Create/list album, add/remove photos, album detail, ownership rules |
| **M5** | **Date Planner (manual)** | Tạo/lưu/sửa/xem lịch hẹn, budget/interests input, date plan data model |

**Sprint 2 integration interfaces:**

- M1 tạo `Photo` + API truy cập an toàn để M2 và M4 đọc dữ liệu.
- M2 chỉ sở hữu timeline/reaction, **không** tự implement pipeline upload của M1.
- M3 quản lý event; M5 quản lý date plan; nếu tạo event từ plan thì dùng service/API được thống nhất.
- M4 quản lý album và liên kết Photo ID đã được kiểm tra cùng couple.
- M5 chuẩn bị contract cho AI, nhưng demo Sprint 2 là planner thủ công, **không phụ thuộc AI**.

**Sprint 2 Demo:** A gửi ảnh → B xem ảnh/widget (theo điều kiện OS), timeline/reaction; tạo sự kiện, album và date plan.

## 6.4 Sprint 3 — AI, Quality & Release

| Member | Feature tiếp tục sở hữu | Sprint 3 deliverables |
|---|---|---|
| M1 | Photo Sharing & Widget | Retry upload, bảo vệ object, widget refresh best-effort, push integration, test thiết bị |
| M2 | Timeline & Reactions | Filter/search nếu kịp, index/pagination tuning, test permission/pagination |
| M3 | Couple Space & Calendar | Nhắc ngày kỷ niệm, timezone, event notification (nếu kịp), acceptance test |
| M4 | Album & AI Memory Story | Consent, AI generation draft, edit/save story, fallback và logging an toàn |
| M5 | Date Planner & AI Recommendations | AI prompts, schema output, edit/save plan, fallback, cost/rate-limit policy |

**Sprint 3 Demo:** toàn bộ core flows, 2 AI flows, access control, Docker environment, test report, deploy staging và document cho báo cáo.

## 6.5 Definition of Done cho mọi task

- Có issue (owner, scope, acceptance criteria) và branch `feature/ISSUE-ID-description`.
- Code/test/review thông qua Pull Request, CI xanh và không có bug blocker.
- API/DB thay đổi đã cập nhật OpenAPI/migration/tài liệu.
- Có demo hoặc screenshot/log test phù hợp; không chứa dữ liệu thật của couple.
- Người sở hữu feature viết được phần **thiết kế–triển khai–kiểm thử** để đưa vào báo cáo.

## 6.6 Nhịp phối hợp

- Kickoff đầu tuần: chốt sprint scope, API/data dependencies.
- Daily async check-in: Done / Next / Blocker (5–10 phút).
- Ít nhất **2 lần/tuần** tích hợp lên `develop`, kiểm tra các flow liên quan.
- Sprint Review: demo sản phẩm; Retrospective: nguyên nhân trễ, điều chỉnh backlog.

## 6.7 Rủi ro về khối lượng

M1 phụ trách widget là rủi ro kỹ thuật cao; cần proof-of-concept Android sớm và xác minh iOS trước khi hứa demo cross-platform. M4/M5 có AI cần chuẩn bị policy/SDK từ Sprint 2, nhưng không làm AI trước chức năng cơ bản. Nếu trễ, cắt filter nâng cao, reminder phức tạp và polish trước, không cắt pairing, photo sharing và authorization.
