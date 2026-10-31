# 12. Open Decisions & Risks

## 12.1 Những quyết định cần chốt ở Sprint 1 Kickoff

| ID | Vấn đề | Đề xuất mặc định | Deadline |
|---|---|---|---|
| OD-01 | Platform ưu tiên demo | Đã chốt iOS-only; iOS widget cần kiểm chứng trên iPhone thật | Đã chốt |
| OD-02 | File/image storage | Chọn một private object storage adapter, tránh public URLs | Week 1–2 |
| OD-03 | Khi unpair giữ/xóa album, ảnh, plans thế nào? | Thiết kế consent, retention và user-facing warning trước implementation | Week 1 |
| OD-04 | JWT/session/refresh policy | JWT access token ngắn hạn; refresh/revoke quyết định chính thức | Week 1 |
| OD-05 | Widget update guarantee | Best-effort + hiển thị thời gian ảnh mới nhất, không hứa realtime tuyệt đối | Week 1 |
| OD-06 | SDK/library versions | Khóa trong build files + CI | Week 1 |
| OD-07 | Invite length/TTL/attempt limits | Mã khó đoán, hết hạn, rate limit, không ghi log raw code | Week 1 |
| OD-08 | API validation/error codes | Chốt contract trước khi FE dùng mock | Week 1 |
| OD-09 | Chọn provider AI và ngân sách | Có budget cap và free fallback demo | Week 6–8 |
| OD-10 | Ngày chạy sprint, giờ làm mỗi thành viên | Chốt trong lịch nhóm, 4 tuần là giả định | Week 1 |

## 12.2 Risk register

Quyết định implementation local của M3 cho OD-04/OD-08: JWT HS256 mặc định 1 giờ,
chưa refresh/revoke; validation 422, JSON hỏng/unknown fields 400; error codes ổn định.
Chi tiết và giới hạn: [M3 Sprint 1](13-m3-sprint1-delivery.md). Nhóm cần review khi tích hợp.

| Risk | Tác động | Mitigation |
|---|---|---|
| Widget iOS không cập nhật như kỳ vọng | Cao | Proof-of-concept sớm, fallback app feed, mô tả giới hạn OS |
| Pairing race condition | Cao | DB unique active membership + transaction + concurrency test |
| Lộ ảnh vì public storage URL | Rất cao | Private storage, auth/short-lived signed URL, security tests |
| API contract lệch giữa 5 người | Cao | Freeze v1 sớm, mocks, OpenAPI và PR review |
| Flyway migration conflict | Trung bình | Quản lý version, migration mới, test clean DB |
| AI API rate limit/cost | Trung bình | Budget cap, timeout, retry, schema validation, fallback |
| Một người phụ thuộc feature khác | Trung bình | Interface contracts, fixtures, mock services, tích hợp hàng tuần |
| Scope quá rộng với 5 người | Cao | Giữ P0, cắt P2; Sprint 2 không phụ thuộc AI |

## 12.3 Quy tắc thay đổi phạm vi

Feature mới muốn thêm phải có owner, tác động dependency và feature nào sẽ bị giảm phạm vi. Tránh thêm chat realtime/video call trước khi photo sharing và pairing được kiểm thử.

## 12.4 Chưa được xác nhận

- Tên thật 5 thành viên và leader/scrum facilitator.
- Ngày bắt đầu/kết thúc thực tế và thời gian rảnh mỗi người.
- iOS WidgetKit và push/APNs cần iPhone thật để kiểm chứng; chưa được coi là hoàn thành.
- Chi phí hosting/storage/AI, choice provider và chính sách retention.
