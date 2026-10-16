# 09. Test Plan & Acceptance Test Matrix

## 9.1 Chiến lược kiểm thử

- **Unit:** domain services/validation, invite expiry, calculation anniversary, AI schema validation.
- **Integration:** controller + auth/security + DB migrations + storage adapter mocking.
- **Mobile widget/UX:** emulator và **ít nhất thiết bị thật** nếu có, vì widget trên OS có nhiều hạn chế.
- **E2E:** 2 tài khoản A/B + tài khoản C để kiểm tra phân quyền.
- **CI:** chạy unit + integration tối thiểu trên PR.

## 9.2 Sprint 1 acceptance matrix

| TC-ID | Kịch bản | Mong đợi |
|---|---|---|
| TC-01 | Đăng ký hợp lệ | 201, user được lưu, không expose password hash |
| TC-02 | Email đăng ký trùng | 409, error code ổn định |
| TC-03 | Login sai password | Không tạo JWT, lỗi an toàn |
| TC-04 | GET /users/me không có JWT | 401 |
| TC-05 | Sửa profile người khác bằng forged ID | Bị từ chối; không truy cập user khác |
| TC-06 | A tạo mã, B nhập mã hợp lệ | 201, couple có đúng A/B |
| TC-07 | A nhập mã do A tạo | 400/409, từ chối tự ghép |
| TC-08 | B nhập mã hết hạn/đã dùng | 400/409, không tạo couple |
| TC-09 | A/B đã có couple active vẫn nhận mã khác | Từ chối |
| TC-10 | Hai request nhận 2 mã khác nhau cùng lúc cho 1 user | Không tạo hai membership active |
| TC-11 | Logout/login lại | Ghép đôi còn tồn tại |
| TC-12 | Hủy ghép đôi | Phản hồi đúng; dữ liệu theo policy thống nhất |

## 9.3 Sprint 2–3 acceptance matrix

| TC-ID | Kịch bản | Mong đợi |
|---|---|---|
| TC-13 | A gửi ảnh hợp lệ | Private storage + metadata thuộc couple |
| TC-14 | File không hợp lệ/quá lớn | Trả 4xx, không sinh photo hoàn chỉnh |
| TC-15 | User C lấy ảnh của couple A/B | 403/404, không lộ ảnh |
| TC-16 | Mạng đứt lúc upload, retry | Không tạo ảnh trùng không chủ đích |
| TC-17 | Timeline có nhiều ảnh | Pagination/cursor không lặp hoặc bỏ ảnh |
| TC-18 | Reaction tạo/thay/xóa | Quy tắc 1 reaction/user/photo được giữ |
| TC-19 | Thêm ảnh của couple khác vào album | Bị từ chối |
| TC-20 | Widget trên thiết bị hỗ trợ | Hiển thị ảnh cache/lần cập nhật hợp lệ; không hứa realtime tuyệt đối |
| TC-21 | Sự kiện ở timezone khác | Date/time hợp lý; không trôi ngày |
| TC-22 | AI không có consent | Backend không gọi provider |
| TC-23 | AI timeout hoặc trả JSON sai schema | Graceful error/fallback, không lưu nội dung lỗi là kết quả final |
| TC-24 | User sửa AI draft và lưu | Lưu bản user duyệt, không tự gửi cho partner |
| TC-25 | Leak attempt (log/token/photo URL) | Không chứa secret hoặc public long-lived photo URL |

## 9.4 Demo cuối từng Sprint

- **S1:** 2 users register/login, A tạo mã, B join, couple profile và unpair edge case.
- **S2:** A gửi ảnh, B thấy ảnh trong app/widget khi OS cho phép; timeline/reaction; album; calendar; date plan thủ công.
- **S3:** Album → chọn ảnh → AI story draft → edit/save; budget/interests → AI plan draft → edit/save; staging health and tests.

## 9.5 Bug policy

- **Blocker/P0:** auth bypass, lộ ảnh private, mất dữ liệu, lỗi pairing hai couple active → không release.
- **P1:** flow chính thất bại, app crash phổ biến → phải khắc phục trước demo.
- **P2:** lỗi UI nhỏ, filter nâng cao → backlog nếu không ảnh hưởng core demo.

## 9.6 Test evidence

Với mỗi feature owner: lưu test case list, screenshot **dữ liệu giả**, CI run link/PR link, mô tả expected vs actual và bug đã sửa. Không dùng ảnh kỷ niệm thật trong báo cáo nếu không được phép.
