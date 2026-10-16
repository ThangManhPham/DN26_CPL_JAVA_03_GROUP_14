# OurSpace — AI-Powered Couple App

**Trạng thái:** Project documentation v1.0 — bản thiết kế để nhóm 5 người thống nhất trước khi triển khai.  
**Kế hoạch:** 3 sprint × 4 tuần (dự kiến, ngày bắt đầu chưa xác định).  
**Mục tiêu:** Xây dựng ứng dụng couple dành cho 2 người, có chia sẻ ảnh và widget kiểu Locket, nhật ký ảnh, kỷ niệm và 2 tính năng AI.

## Bắt đầu đọc từ đâu?

| Tài liệu | Nội dung |
|---|---|
| [01 — Tổng quan sản phẩm](docs/01-product-overview.md) | Tầm nhìn, đối tượng, MVP và phạm vi |
| [02 — Yêu cầu & user stories](docs/02-requirements.md) | Chức năng, acceptance criteria, NFR |
| [03 — Kiến trúc hệ thống](docs/03-architecture.md) | Luồng dữ liệu, stack, modules, sơ đồ Mermaid |
| [04 — Thiết kế database](docs/04-database.md) | ERD đề xuất, ràng buộc, Flyway |
| [05 — API contract](docs/05-api-contract.md) | Endpoint v1, DTO, status/error format |
| [06 — Sprints & phân công](docs/06-sprints-ownership.md) | 25 task Sprint 1, owner của 5 feature, dependency |
| [07 — Dev environment](docs/07-local-development.md) | Docker, .env, các chế độ chạy local |
| [08 — Git & CI](docs/08-git-cicd.md) | Workflow PR, branch, Definition of Done |
| [09 — Testing](docs/09-test-plan.md) | Test matrix, E2E flow, security checklist |
| [10 — AI & privacy](docs/10-ai-and-privacy.md) | Hai AI feature, consent, rate limit, fallback |
| [11 — Hướng dẫn báo cáo](docs/11-report-outline.md) | Báo cáo tổng và trách nhiệm 5 thành viên |
| [12 — Quyết định còn mở](docs/12-open-decisions.md) | Các điều cần chốt, không giả định là đã quyết |

## Phạm vi đã thống nhất

- **Sprint 1:** Nền tảng Flutter + Spring Boot + PostgreSQL + Docker Compose + Flyway, đăng ký/đăng nhập, profile, mã mời và ghép đôi.
- **Sprint 2:** 5 feature ownership end-to-end: Photo Sharing & Widget; Timeline & Reactions; Couple Space & Calendar; Memory Album; Date Planner.
- **Sprint 3:** Hoàn thiện 5 feature; tích hợp AI Memory Story và AI Date Planner; test, staging và báo cáo.
- **Tổ chức:** Sprint 1 chia theo vai trò; Sprint 2–3 mỗi người **chịu trách nhiệm chính một feature**, làm được luồng Flutter → API → DB → test.

> **Lưu ý:** Đây là documentation/blueprint, **chưa phải source code hoàn chỉnh**. Các API/schema dưới đây là hợp đồng **đề xuất**, cần khóa phiên bản tại buổi kickoff. Widget hệ điều hành không bảo đảm ảnh cập nhật ngay tức thì. AI chỉ truy cập dữ liệu người dùng chủ động cho phép.

## Quy tắc sử dụng docs

1. Nếu đổi API/schema, cập nhật Markdown tương ứng trong cùng PR.
2. Database thay đổi thông qua Flyway migration; không tự sửa schema bằng tay giữa các máy.
3. Tránh commit token, thông tin người dùng thật, mật khẩu, API key hay ảnh riêng tư.
4. Trong báo cáo, phân biệt rõ **đã triển khai** với **thiết kế dự kiến**.
