# M3 — tích hợp lịch Flutter từ main và carry-over Sprint 3

## Phạm vi

Theo dòng M3 trong [review 05/11/2026](17-sprint2-review-sprint3-carryover.md):
đưa ngày kỷ niệm, bộ đếm và CRUD sự kiện vào ứng dụng Flutter/iOS hiện tại,
dùng backend đã merge ở PR #10. Nhánh triển khai:
`feature/S3-M3-calendar-integration`, nền `main` tại `af1b7df`.

Đây là giao diện ứng dụng của nhóm, riêng với web demo cá nhân ngoài repository.
Không đưa web demo, tài khoản cá nhân hay video vào thay đổi này. Reminder/push
không thuộc dòng carry-over P0 này và chưa được triển khai trong thay đổi này.

## Luồng và tích hợp

- Login → pairing gate → Couple Home → **Ngày kỷ niệm & lịch chung**.
- Chọn ngày kỷ niệm qua date picker; số ngày lấy từ backend (ngày đầu = 0).
- Lịch tháng đánh dấu các ngày có sự kiện, kể cả sự kiện qua ngày/tháng.
- Tạo/sửa sự kiện có tên, ghi chú, ngày/giờ bắt đầu và kết thúc; xóa cần xác nhận.
- Đọc bản mới trước khi sửa. Xung đột 409 giữ bản nháp, khóa lưu và cho người dùng
  chủ động **Tải bản mới (thay nội dung đang nhập)** trước khi sửa tiếp.
- Tải lại khi bấm refresh hoặc app trở lại foreground; quay về Home cũng nạp
  lại couple để ngày kỷ niệm hiển thị ở Home được cập nhật.
- Loading, empty, retry khi mất mạng, không có couple và lỗi lưu đều có trạng thái UI.
- `ApiCalendarRepository` dùng `ApiClient` chung, không tạo HTTP stack/JWT storage
  riêng. 401 xóa phiên và đóng cả editor/calendar để quay lại Login; dữ liệu cũ
  không còn nằm trên các route đang mở sau logout.
- Mock nội bộ `USE_MOCK=true` chưa có contract calendar: nút lịch bị vô hiệu kèm
  giải thích. Dùng backend Spring Boot thật để demo; không coi mock là bằng chứng tích hợp.

## TC-21: timezone và ngày kỷ niệm

Ngày kỷ niệm là ngày lịch, serialize `YYYY-MM-DD`, không đổi sang UTC.
Sự kiện là thời điểm tuyệt đối: nhập theo timezone thiết bị, gửi UTC; dữ liệu
trả về được chuyển về timezone thiết bị để hiển thị. Metadata offset lấy theo
**ngày sự kiện**, không dùng offset hôm nay (tránh sai khi qua DST).

Ví dụ: 02/11/2026 00:30 tại UTC+7 được lưu thành `2026-11-01T17:30:00Z`.
Thiết bị có timezone khác thấy giờ địa phương tương ứng cùng thời điểm, không
được ép cùng ngày/giờ hiển thị giữa hai timezone. Range tháng dùng hai mốc nửa
đêm local chuyển sang UTC; ranh giới ngày tính bằng ngày lịch, không cộng cố định
24 giờ ở nơi có DST.

Backend tests có clock cố định: UTC/Hồ Chí Minh/Los Angeles ở ranh giới ngày;
New York sau chuyển DST, 23 giờ đã trôi qua vẫn là một ngày lịch.

## Chạy với backend thật

```powershell
cd backend
mvn package
mvn spring-boot:run '-Dspring-boot.run.profiles=dev'
```

Trên Mac có Xcode/iOS Simulator:

```sh
cd mobile
flutter pub get
flutter run --dart-define=OURSPACE_API_BASE_URL=http://localhost:8080
```

Không truyền `USE_MOCK=true`. Với iPhone thật, truyền URL backend mà điện thoại
truy cập được và cấu hình Firebase/signing theo tài liệu iOS của M1.

Đăng ký A/B, A tạo invite, B join. A vào lịch đặt ngày và tạo cuộc hẹn; B vào
cùng ngày để đọc, sửa và xóa. A refresh để đối chiếu. Có thể tạo couple C/D để
kiểm tra C không xem được sự kiện A/B bằng UUID. Khi kiểm tra timezone trên hai
thiết bị, dùng ví dụ sát nửa đêm ở trên và đối chiếu UTC trong response.

## Kiểm thử tự động

```powershell
cd mobile
flutter pub get
flutter analyze
flutter test
```

`calendar_repository_test`: civil date, JWT, timezone query, UTC round-trip,
phân trang và phát hiện pagination lặp, version PATCH/DELETE, 401/409.
`calendar_screen_test`: kích thước 390×844 với theme iOS, create/edit/delete và
hủy xác nhận, tên rỗng, conflict/reload, network retry, unpaired và expired session.
`calendar_navigation_test`: Home → Calendar → Editor, hết phiên đóng route về Login.

`calendar_backend_acceptance_test` mặc định skip khi không có server riêng.
Chạy đầy đủ qua helper, tự tạo và dừng backend loopback/H2 độc lập:

```powershell
cd backend
mvn package
./scripts/smoke-calendar-flutter.ps1 -FlutterCommand flutter
# Hoặc chạy toàn bộ Flutter suite, gồm ca backend thật:
./scripts/smoke-calendar-flutter.ps1 -FlutterCommand flutter -AllTests
```

Nếu Flutter không có trên PATH, truyền đường dẫn đầy đủ tới `flutter.bat`.
Máy dùng JDK 25 cần `mvn package '-Dnet.bytebuddy.experimental=true'` do dependency
test Byte Buddy hiện tại; project vẫn target Java 21.

Helper chạy client Flutter thật → JWT/login/pairing Spring Boot → Flyway/JPA/H2:
A/B chia sẻ ngày và sự kiện, UTC gần nửa đêm, đọc/list/sửa, stale version 409,
invalid time 422 không thay dữ liệu, couple khác 404, delete và invalid JWT 401.
Không dùng mock HTTP, database cấu hình sẵn hay database web demo.

## Giới hạn bằng chứng

Kết quả local ngày 05/11/2026:

- Backend `mvn package`: **67 tests pass**, 0 failure/error/skip, JAR build thành công.
- Toàn bộ Flutter suite với `CALENDAR_API_BASE_URL` trỏ backend độc lập:
  **64 tests pass**, bao gồm acceptance qua HTTP thật (không skip ca này).
- `flutter analyze`: **No issues found**.
- Helper `smoke-calendar-flutter.ps1`: **PASS**, tự dựng/dừng server và DB riêng.
- Render kiểm tra bố cục 390×844/theme iOS: không overflow, thao tác CRUD/conflict
  kiểm tra hit-test thành công. Ảnh QA và file xuất ảnh chỉ lưu local ngoài repo.

Windows kiểm tra được Dart/Flutter unit/widget và HTTP thật. Chưa thể xác nhận
build iOS, ký ứng dụng, iPhone thật hoặc E2E PostgreSQL/staging từ kết quả này.
Nhóm cần chạy trên Mac/iPhone và PostgreSQL trước khi đóng task theo DoD.
Flutter SDK local là 3.41.6/Dart 3.11.4, đáp ứng pubspec; `pub get` điều chỉnh
dependency SDK-pinned tương ứng. Nhóm dùng SDK khác cần resolve bằng SDK của nhóm
và chạy lại CI. Không thêm dependency trực tiếp cho calendar.
