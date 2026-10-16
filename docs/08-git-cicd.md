# 08. Git Workflow, Code Review & CI/CD

## 8.1 Branch workflow

```text
main      = bản demo/release ổn định
develop   = tích hợp sprint hiện tại
feature/S1-12-register-login
feature/S2-photo-widget
fix/S1-20-invite-race
```

- Mỗi issue có 1 owner chính; không làm trực tiếp trên `main`.
- Pull Request về `develop`, **ít nhất 1 reviewer** khác owner.
- Rebase/merge conflict được xử lý bởi owner PR; PR cần cập nhật với `develop` mới.
- Đến cuối sprint, kiểm thử trên `develop`, merge có kiểm soát sang `main` và tag `sprint-1-demo` v.v.

## 8.2 PR template đề xuất

```markdown
## Summary
- 
## Linked issue
- Closes #...
## Changes
- [ ] Flutter
- [ ] Spring Boot
- [ ] Flyway/database
- [ ] Docs/API contract
## How tested
- Unit:
- Integration:
- Manual demo:
## Security / privacy impact
- 
## Screenshots / recording (sanitized)
- 
```

## 8.3 CI pipeline tối thiểu

1. **Backend:** JDK + dependency cache → compile → unit/integration tests → package.
2. **Flutter:** setup SDK → `flutter pub get` → `flutter analyze` → `flutter test`.
3. **Migration smoke:** chạy PostgreSQL test và Flyway migration ít nhất ở CI tích hợp backend.
4. Optional: static analysis, secret detection, dependency vulnerability scan.

M5 build workflow CI; feature owner sửa lỗi tests của PR mình, không đẩy hết về M5.

## 8.4 Git collaboration rules

- Squash merge để history rõ issue; commit message `feat(pairing): accept invite [S1-18]`.
- Không commit `build/`, `.idea/` nội dung cá nhân, credential, local media, dữ liệu DB.
- Mỗi schema change = migration **mới**. Không chỉnh file Flyway đã áp dụng trên `develop`/staging.
- Không đổi endpoint/DTO breaking một mình; thông báo người phụ thuộc, cập nhật mocks và OpenAPI.
- CI pass là **điều kiện cần**, không thay cho review behavior/security.

## 8.5 Definition of Ready

Một issue có thể bắt đầu khi có: user story/task description, owner, các contract cần thiết, acceptance criteria, dependency và mock data nếu backend chưa sẵn sàng.

## 8.6 Definition of Done

PR merged + tests pass + docs cập nhật + owner demo + không có blocker + chứng cứ đóng góp (issue/PR) đã lưu.
