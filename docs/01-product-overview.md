# 01. Tổng quan sản phẩm (Product Vision & Scope)

## 1.1 Bài toán

Các cặp đôi cần một không gian riêng để chia sẻ khoảnh khắc nhỏ mỗi ngày và lưu các kỷ niệm theo thời gian. OurSpace kết hợp photo sharing (ảnh hiển thị trên home-screen widget), timeline, các cột mốc quan trọng và AI hỗ trợ kể lại kỷ niệm/lên kế hoạch hẹn hò.

## 1.2 Tuyên bố sản phẩm

**OurSpace** là ứng dụng mobile dành cho một cặp đôi gồm đúng hai tài khoản đã ghép nối; dùng để chia sẻ ảnh, tương tác, lưu kỷ niệm và có trợ lý AI phục vụ các hoạt động chung. Không xây mạng xã hội công khai.

## 1.3 Vai trò và người dùng

- **Guest:** chỉ đăng ký và đăng nhập.
- **Authenticated User chưa ghép đôi:** sửa profile, tạo/nhập mã mời.
- **Paired User:** quản lý nội dung chung với người yêu; chỉ truy cập nội dung của chính cặp đôi.
- **Backend/System:** xác thực, phân quyền, lưu metadata, thông báo và điều phối AI.

## 1.4 Phạm vi và ưu tiên

| Nhóm | Feature | Kế hoạch |
|---|---|---|
| P0 | Tài khoản, profile, pairing, unpairing | Sprint 1 |
| P0 | Upload/send photo, nhận ảnh trong app, widget khả dụng | Sprint 2 |
| P0 | Timeline, ảnh chi tiết, reaction | Sprint 2 |
| P1 | Couple Space: đếm ngày yêu, sự kiện/lịch chung | Sprint 2 |
| P1 | Album chung và quản lý ảnh trong album | Sprint 2 |
| P1 | Date Planner thủ công, lưu/đổi kế hoạch | Sprint 2 |
| P1 | AI Memory Story; AI Date Planner | Sprint 3 |
| P1 | Bảo mật, test, staging, documentation | Xuyên suốt |
| P2 | Tìm kiếm ảnh, bộ lọc, nhắc kỷ niệm nâng cao | Sprint 3 nếu kịp |

**Ngoài phạm vi 3 sprint:** mạng xã hội công khai, video call, chat realtime đầy đủ, nhận diện khuôn mặt, tự huấn luyện model AI, hệ thống thanh toán, microservices/Kubernetes.

## 1.5 Luồng người dùng chính

1. Người A đăng ký, đăng nhập và tạo mã mời có thời hạn.
2. Người B đăng ký, đăng nhập, nhập mã → hai tài khoản được ghép đôi.
3. A chụp ảnh, gửi; B nhận notification (nếu cho phép) và có thể xem ảnh trong app/widget khi hệ điều hành cập nhật.
4. Cả hai xem timeline, reaction, album và lịch chung.
5. Người dùng tự chọn ảnh/ghi chú để AI tạo Memory Story; hoặc nhập nhu cầu để AI gợi ý date plan.
6. Người dùng có thể hủy ghép đôi. Chính sách giữ/xóa dữ liệu chung cần được chốt trước khi triển khai.

## 1.6 Tiêu chí thành công

- Demo end-to-end từ 2 tài khoản trên 2 thiết bị, không cần dữ liệu tạo bằng tay trong DB.
- Phân quyền: tài khoản thứ ba không thể đọc/ghi tài nguyên của cặp đôi.
- Backend và DB tái tạo bằng Docker Compose; schema cập nhật bằng migration.
- Có ít nhất một kịch bản hoạt động cho mỗi 5 feature ownership; 2 AI features hoạt động với dữ liệu đã cho phép.
- PR/issue/test/documentation hỗ trợ truy vết đóng góp cá nhân.

## 1.7 Giả định

- Thời gian 12 tuần là giả định quy hoạch, không phải lịch đã được xác nhận.
- Flutter được chọn theo định hướng cross-platform; tính khả thi iOS thực tế phụ thuộc thiết bị macOS/Xcode và test widget.
- Tên OurSpace là tên làm việc, cần kiểm tra trademark nếu phát hành công khai.
