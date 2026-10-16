# 02. Functional Requirements & User Stories

## 2.1 Functional requirements

| ID | Requirement | Sprint | Priority |
|---|---|---:|---|
| FR-01 | Đăng ký/đăng nhập bằng email và password, hash password phía server | 1 | P0 |
| FR-02 | Xem/sửa hồ sơ của chính mình | 1 | P0 |
| FR-03 | Sinh mã ghép đôi hết hạn, mỗi tài khoản tối đa 1 couple active | 1 | P0 |
| FR-04 | Chấp nhận mã mời và đọc trạng thái cặp đôi | 1 | P0 |
| FR-05 | Hủy ghép đôi theo chính sách dữ liệu thống nhất | 1 | P0 |
| FR-06 | Chụp/chọn ảnh, gửi cho couple, xem trạng thái upload | 2 | P0 |
| FR-07 | Xem ảnh mới nhất qua app; widget hiển thị ảnh khi OS cập nhật | 2 | P0 |
| FR-08 | Timeline có pagination và reaction | 2 | P0 |
| FR-09 | Đếm ngày yêu, tạo và xem sự kiện riêng của couple | 2 | P1 |
| FR-10 | Tạo album, thêm/bỏ ảnh, xem ảnh trong album | 2 | P1 |
| FR-11 | Tạo và lưu date plan thủ công | 2 | P1 |
| FR-12 | AI Memory Story từ dữ liệu tự chọn, duyệt trước khi lưu/chia sẻ | 3 | P1 |
| FR-13 | AI Date Planner từ ngân sách, thời gian, sở thích, có thể chỉnh sửa | 3 | P1 |
| FR-14 | Thông báo push có kiểm soát opt-in và trạng thái permission | 2–3 | P1 |

## 2.2 User stories & acceptance criteria

### US-01 — Đăng ký/đăng nhập

**As a** new user, **I want** đăng ký và đăng nhập, **so that** tôi sử dụng được OurSpace.

- Email hợp lệ; mật khẩu đáp ứng policy tối thiểu; không trả password hash.
- Email trùng trả HTTP 409 với mã lỗi ổn định.
- Sai thông tin đăng nhập không tiết lộ email có tồn tại hay không.
- Request được validate; endpoint bảo vệ bằng authentication khi cần.

### US-02 — Pairing

**As a** user chưa ghép đôi, **I want** dùng mã mời để kết nối người yêu.

- Mã hợp lệ, chưa sử dụng, chưa hết hạn; không được ghép với chính mình.
- Không người dùng nào có 2 mối ghép **active** cùng lúc, kể cả khi 2 request đồng thời.
- Sau khi ghép đôi, cả hai nhìn thấy nhau trên Couple Home.
- Mã sai/hết hạn/đã dùng trả error code cụ thể, không lộ thông tin nhạy cảm.

### US-03 — Photo sharing

- Chỉ 2 thành viên thuộc couple mới được tải/xem ảnh.
- Ảnh được giới hạn dung lượng/định dạng; upload lỗi có thể thử lại mà không tạo bản ghi trùng.
- Trạng thái ảnh hiển thị trong app; widget là best-effort do chính sách cập nhật OS.

### US-04 — Timeline & reaction

- Timeline chỉ gồm ảnh của couple, sắp theo thời gian, có cursor hoặc pagination.
- Reaction của mỗi user trên một ảnh tuân theo quy tắc đã chốt (ví dụ một reaction hiện hành).
- Tài khoản ngoài couple nhận 403/404 mà không lộ metadata.

### US-05 — AI Memory Story

- Người dùng **chủ động** chọn ảnh/ghi chú, xác nhận gửi sang AI.
- Kết quả trả về ở trạng thái draft và có thể sửa trước khi lưu.
- Khi timeout/rate limit, app hiển thị lỗi rõ và cho thử lại.

### US-06 — AI Date Planner

- Input gồm ngân sách, khu vực, thời lượng, sở thích; phải validate giá trị.
- AI tạo kế hoạch mang tính gợi ý, không tự nhận là địa điểm/giờ mở cửa đã xác minh.
- Người dùng sửa và lưu được plan; không tự động đặt dịch vụ hay chia sẻ vị trí.

## 2.3 Non-functional requirements

| ID | Mục tiêu / kiểm chứng |
|---|---|
| NFR-01 Security | HTTPS tại staging/prod, JWT, role/ownership check ở mọi resource, hash password, secrets ngoài Git |
| NFR-02 Privacy | Không public ảnh; consent rõ ràng với AI; chức năng xóa dữ liệu theo chính sách |
| NFR-03 Reliability | Xử lý lỗi mạng/upload/AI gracefully, có retry giới hạn và logging |
| NFR-04 Portability | Backend/DB chạy được qua Compose trên máy của 5 thành viên |
| NFR-05 Testability | Có unit tests cho service, integration tests cho auth/pairing/photo quyền truy cập |
| NFR-06 Performance | Phân trang timeline, giới hạn upload, nén ảnh phía client khi phù hợp |
| NFR-07 Observability | Log có requestId, không log JWT, invite code, nội dung ảnh, prompt riêng tư |

> Chưa chốt số liệu SLA/latency hay load target. Sprint 1 đo baseline trước, sau đó bổ sung ngưỡng có cơ sở.
