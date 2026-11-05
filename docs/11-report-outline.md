# 11. Đề cương báo cáo và chứng cứ đóng góp

## 11.1 Cấu trúc báo cáo nhóm đề xuất

1. **Introduction** — bài toán, mục tiêu, phạm vi, nghiên cứu sản phẩm tương tự.
2. **Requirement Analysis** — actors, use case, user stories, NFR, risk.
3. **System Design** — architecture, ERD, module boundaries, API/security.
4. **Implementation** — công nghệ, Docker, CI, các feature theo owner.
5. **Testing & Evaluation** — test matrix, demo, security/AI/widget limitations.
6. **Conclusion & Future Work** — thành quả thật, hạn chế và hướng phát triển.

## 11.2 Mỗi cá nhân báo cáo một feature

| Member | Chương/tiểu mục cá nhân | Đầu ra dùng chứng minh |
|---|---|---|
| M1 | Photo Sharing & iOS WidgetKit | upload flow, object storage, push, test iPhone; widget chỉ báo cáo khi thực sự triển khai |
| M2 | Timeline & Reactions | pagination, reaction schema/API, UI/test access control |
| M3 | Couple Space & Shared Calendar | love counter, calendar schema, timezone, event flows |
| M4 | Memory Album & AI Memory Story | album relationships, prompt design, AI output validation |
| M5 | Date Planner & AI Recommendations | date plan model, AI orchestration, budget/cost, fallback |

Lưu ý **Sprint 1 công việc nền tảng vẫn ghi công đúng** theo PR: M1 UI/Auth; M2 Flutter Core/Pairing; M3 Backend Auth; M4 DB/Pairing; M5 DevOps/CI. Việc đổi sang feature ownership từ Sprint 2 **không xóa đóng góp Sprint 1**.

## 11.3 Template tiểu mục cá nhân

1. Feature Overview & Reasoning
2. Use Case và yêu cầu chức năng
3. UI Flow/Wireframe
4. Data Model/Database Tables
5. API Endpoints & Validation
6. Main Implementation (Flutter ↔ Spring Boot ↔ DB/External Service)
7. Security, Error Handling, Performance
8. Test Cases, Test Results, Screenshots
9. Đóng góp cụ thể (issue/PR/commit) và bài học

## 11.4 GitHub artifacts cần giữ

- Issues/Projects board với owner, state, acceptance criteria.
- Pull Request và reviewer comments chứng minh code review.
- Test reports/CI result, staging demo, screenshots dùng dữ liệu giả.
- ERD revision, API OpenAPI spec, design decisions (ADR) theo thời điểm.
- Changelog mỗi Sprint: planned, completed, deferred, risk, mitigation.

## 11.5 Quy tắc trung thực khi viết báo cáo

- Không ghi tính năng dự kiến như đã hoàn thành.
- Nếu iOS widget chưa triển khai/kiểm thử trên iPhone thật, ghi rõ là chưa hoàn thành.
- Nếu AI trả kết quả mô phỏng, không viết là đã gọi provider thật.
- Nếu sử dụng API/hosted model, gọi là **AI integration** thay vì tự huấn luyện AI.
- Tránh dùng screenshot ảnh riêng tư/có thông tin thật chưa được phép.
