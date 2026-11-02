# M2 — Flutter Mobile (iOS/Web): Sprint 1 & Sprint 2

> Nhánh: `thang_m2_sprint1&2`. Người thực hiện: Phạm Mạnh Thắng (DE190404).
> Phạm vi: chỉ iOS, chạy Flutter Web để test/demo. Không sửa code backend/CI/Docker.

## 1. Tóm tắt

| Hạng mục | Kết quả |
|---|---|
| `flutter analyze` | **No issues found!** |
| `flutter test` | **37/37 pass** |
| Flutter / Dart | Flutter 3.47.9 (stable) • Dart 3.13.7 |
| Thay đổi cấu hình iOS | **Không có** (giữ nguyên `Info.plist`, deployment target của M1) |
| Ngoài phạm vi | chat, AI, album, event, widget — không làm |

## 2. Hiện trạng trước khi làm (đã có / còn thiếu)

Đã có (M1): `mobile/lib/data/auth_repository.dart`, `photo_repository.dart`, `photo_screen.dart`, `ios_widget_bridge.dart`, `firebase_options.dart`, `mobile/README.md`, `test/auth_repository_test.dart`, `test/photo_repository_test.dart`, `test/widget_test.dart`.

Còn thiếu (M2): cấu trúc feature-first, HTTP client + interceptor + token storage an toàn, auth state (login/logout/restore), luồng ghép đôi (invite) & Couple Home, timeline/reaction. `main.dart` là placeholder, `widget_test.dart` cũ dùng constructor đã lỗi thời.

Đã làm: giữ nguyên pattern M1 (ChangeNotifier + `AnimatedBuilder`, repository theo contract), tái sử dụng `AuthRepository`/`PhotoRepository` sẵn có và **viết thêm** lớp `core/` + `features/` cho M2, không dựng kiến trúc mới.

## 3. Use case

**Sprint 1 — Core & Pairing**
- UC1 Đăng nhập/đăng xuất/khôi phục phiên khi mở app; token tự động gắn vào mọi request.
- UC2 Phiên hết hạn (401) → xóa phiên và quay về màn Login.
- UC3 Tạo mã mời (6 ký tự, hạn 24h) và sao chép/chia sẻ.
- UC4 Nhập mã để ghép đôi; xử lý mã sai, hết hạn, đã dùng, tự ghép với chính mình, người gửi đã có cặp.
- UC5 Xem Couple Home (thành viên, trạng thái, ngày kỷ niệm) và hủy ghép đôi có hộp thoại xác nhận.
- UC6 Router redirect theo trạng thái: chưa đăng nhập → Login; đã đăng nhập chưa ghép → Pairing; đã ghép → Couple Home.

**Sprint 2 — Timeline & Reactions**
- UC7 Timeline của couple: phân trang theo cursor (infinite scroll), kéo-để-làm-mới, skeleton, empty/error.
- UC8 Xem chi tiết ảnh: ảnh (endpoint có xác thực), người gửi, thời gian ISO-8601/UTC hiển thị theo giờ local.
- UC9 Thả/bỏ reaction (mỗi người 1 reaction/ảnh) với optimistic update và rollback khi lỗi.
- UC10 Quyền riêng tư: chỉ xem ảnh trong couple của mình; 403/404 hiển thị gọn gàng; không lưu URL công khai (dùng `imagePath` có xác thực).

## 4. UI flow

```
Splash (khôi phục phiên)
   └─(không có phiên)→ Login/Register
        └─(đăng nhập ok, chưa ghép)→ Pairing
             ├─ Tạo mã mời  → hiện mã + hạn + [Sao chép] [Chia sẻ] [Tạo mã khác]
             └─ Nhập mã     → (ok) → Couple Home
   └─(đã ghép)→ Couple Home
        ├─ [Hồ sơ] → Profile (sửa tên, đăng xuất)
        ├─ [Timeline của hai bạn] → Timeline
        │      ├─ kéo-để-làm-mới / cuộn tới cuối = nạp thêm (cursor)
        │      └─ chạm ảnh → Photo Detail → reaction
        ├─ [Gửi ảnh cho người ấy] → PhotoScreen (M1)
        └─ [Hủy ghép đôi] → dialog xác nhận → (đồng ý) → Pairing
```

Trạng thái hiển thị ở mọi màn: **loading / empty / error** (dùng `LoadingStateView`, `EmptyStateView`, `ErrorStateView` — `core/widgets/async_states.dart`).

## 5. Endpoints sử dụng (theo `docs/05-api-contract.md`)

| Chức năng | Method + Path | Ghi chú |
|---|---|---|
| Tạo mã mời | `POST /api/v1/couple-invites` | → `{ inviteCode, expiresAt }` (201) |
| Nhập mã | `POST /api/v1/couples/join` | body `{ "inviteCode": "K7P4R8" }` → couple (201) |
| Thông tin cặp đôi | `GET /api/v1/couples/me` | 200 couple hoặc **404** → coi như chưa ghép |
| Hủy ghép đôi | `DELETE /api/v1/couples/me` | 204, UI bắt buộc xác nhận |
| Timeline | `GET /api/v1/photos?cursor=&limit=` | `{ items, nextCursor }`; `limit` mặc định 20 |
| Chi tiết ảnh | `GET /api/v1/photos/{id}` | `PhotoResponse` |
| Tải ảnh (private) | `GET /api/v1/photos/{id}/image` (qua `imagePath`) | bytes, header xác thực, không dùng URL công khai |
| Thả/thay reaction | `PUT /api/v1/photos/{id}/reaction` | body `{ "type": "LAUGH" }` |
| Bỏ reaction | `DELETE /api/v1/photos/{id}/reaction` | |

**Chuẩn hóa lỗi** (`code, message, details, requestId`) — `core/network/api_exception.dart`, ánh xạ `code` sang thông điệp tiếng Việt. Mã lỗi đã xử lý: `NETWORK_ERROR`, `INVALID_CREDENTIALS`, `UNAUTHORIZED`, `FORBIDDEN`, `INVALID_INVITE_CODE`, `INVITE_EXPIRED`, `CANNOT_PAIR_SELF`, `ALREADY_PAIRED`, `INVITER_ALREADY_PAIRED`, `COUPLE_NOT_FOUND`, `COUPLE_REQUIRED`, `PHOTO_NOT_FOUND`, `VALIDATION_ERROR`.

**Reaction enum** (`photo_reactions.reaction_type`): `LOVE`, `LIKE`, `LAUGH`, `SAD` — `timeline_models.dart`. Reaction type lạ từ backend bị bỏ qua an toàn (không làm hỏng tải timeline).

## 6. Cấu trúc code

```
mobile/lib/
├─ main.dart                         # ráp ApiClient + AuthController + Repository, khởi động app
├─ core/
│  ├─ config/app_config.dart         # USE_MOCK, base URL qua --dart-define
│  ├─ network/api_client.dart        # Dio + interceptor Bearer + xử lý 401
│  ├─ network/api_exception.dart     # chuẩn hóa lỗi theo contract + userMessage
│  ├─ state/auth_controller.dart     # login/logout/restore/updateProfile (ChangeNotifier)
│  ├─ storage/token_storage.dart     # flutter_secure_storage + fallback in-memory (web)
│  ├─ router/app_router.dart         # redirect theo trạng thái phiên
│  ├─ theme/app_theme.dart           # token màu/layout dùng chung + formatLocalDateTime
│  ├─ widgets/{async_states,brand_mark}.dart
│  ├─ services/share_service.dart    # share sheet iOS / Web Share API + clipboard
│  └─ push/                          # abstract + factory + stub(web)/io(iOS)
├─ features/
│  ├─ auth/{data,presentation}/       # models, repository (Api/Mock), AuthScreen, ProfileScreen, validators
│  ├─ pairing/{data,presentation}/    # pairing_models/repository (Api/Mock), PairingGate/Screen, InviteCreate, InviteJoin, CoupleHome, PairingController
│  └─ timeline/{data,presentation}/   # timeline_models/repository (Api/Mock), TimelineController/Screen, PhotoDetailScreen, ReactionBar
└─ data/, photo_screen.dart, ios_widget_bridge.dart, firebase_options.dart   # dùng lại của M1
```

**Mock API**: mỗi feature có `abstract` repository + `Mock*Repository` (độ trễ, case lỗi) + `Api*Repository`, chuyển bằng `--dart-define=USE_MOCK=true`. JSON shape của mock giữ đúng contract (camelCase). Mock mô phỏng: thành công, danh sách rỗng, 403, 404, 401, lỗi tải thêm, reaction lỗi. Mã đặc biệt để demo/test: `EXPYR3` (hết hạn), `US3D22` (mã sai/đã dùng), `S3LF22` (tự ghép), `PAYRD2` (người gửi đã ghép).

## 7. Danh sách test tự động (37 test — đã xanh)

| File | Số test | Nội dung |
|---|---|---|
| `test/core/api_client_test.dart` | 5 | Interceptor Bearer; không ghi đè header có sẵn; 401 → `onUnauthenticated` + `ApiException`; chuẩn hóa `code/message/details/requestId`; mất kết nối → `NETWORK_ERROR` |
| `test/core/auth_controller_test.dart` | 5 | login lưu token; login sai mật khẩu; restore khôi phục phiên; restore xóa token hỏng; `forceLogout` (401) |
| `test/features/timeline_controller_test.dart` | 6 | Cursor pagination tới hết dữ liệu; refresh giữ trang đầu; reaction optimistic; rollback khi lỗi; lỗi 403 bản địa hóa; lỗi tải thêm giữ dữ liệu cũ |
| `test/features/timeline_repository_test.dart` | 5 | `fetchPage` đúng cursor/limit + camelCase; `PUT` reaction body `type`; `DELETE` reaction; `fetchPhoto` bỏ reaction type lạ; `fetchImage` qua endpoint xác thực |
| `test/features/timeline_screen_test.dart` | 6 | Skeleton → danh sách; empty; lỗi 403 + nút thử lại; reaction cập nhật tức thì; reaction lỗi rollback + SnackBar; photo detail đúng giờ local |
| `test/features/pairing_flow_test.dart` | 3 | A tạo mã → B nhập mã → Couple Home → hủy ghép có xác nhận; các case lỗi nhập mã; từ Couple Home mở Timeline |
| `test/widget_test.dart` | 3 | Validate form auth; đăng ký → sửa hồ sơ → đăng xuất → đăng nhập; đăng nhập sai hiện lỗi an toàn |
| `test/auth_repository_test.dart` (M1) | 1 | Contract register/login/profile |
| `test/photo_repository_test.dart` (M1) | 3 | Request ID UUID; ảnh latest qua endpoint xác thực; 404 = empty |

## 8. Checklist test thủ công

Chạy: `flutter run -d chrome --dart-define=USE_MOCK=true` (hoặc iOS Simulator, xem §10).

> **Lưu ý về Test Manual Pairing trên Web (Mock Mode):**
> Do mỗi cửa sổ trình duyệt (window/tab) là một môi trường JS riêng biệt, chúng không chia sẻ bộ nhớ static. Để test luồng ghép đôi A gửi mã cho B thành công ở chế độ Mock, hãy thực hiện **trên cùng một tab**:
> 1. Đăng nhập Alex -> Tạo mã mời (ví dụ `9MEPST`) -> Sao chép mã.
> 2. Đăng xuất (Profile -> Đăng xuất).
> 3. Đăng nhập Sam -> Nhập mã mời đã chép -> Ghép đôi thành công.
>
> (Các mã mời đặc biệt như `EXPYR3`, `US3D22`... hoạt động ở mọi nơi mà không cần bước trên).

### Sprint 1

| Chức năng | Bước test | Kết quả mong đợi | Pass/Fail |
|---|---|---|---|
| Khôi phục phiên | Mở app khi đã đăng nhập | Vào thẳng Pairing/Couple Home, không hỏi lại mật khẩu | |
| Đăng nhập sai | Nhập sai mật khẩu | Báo "Email hoặc mật khẩu không đúng.", không lộ tài khoản tồn tại | |
| 401 | Token hết hạn khi đang dùng | Tự đăng xuất, quay về Login | |
| Tạo mã mời | Login A → "Tạo mã mời" | Mã 6 ký tự, có hạn, nút Sao chép/Chia sẻ hoạt động | |
| Nhập mã sai định dạng | Nhập "AB" → Ghép đôi | "Mã mời gồm 6 ký tự." | |
| Mã hết hạn | Nhập `EXPYR3` | "Mã ghép đôi đã hết hạn." | |
| Mã đã dùng/không tồn tại | Nhập `US3D22` | "Mã ghép đôi không đúng hoặc đã được sử dụng." | |
| Tự ghép | Nhập `S3LF22` | "Không thể tự ghép đôi với chính mình." | |
| Người gửi đã ghép | Nhập `PAYRD2` | "Người gửi mã đã thuộc về một cặp đôi khác." | |
| Ghép đôi (2 tài khoản) | Tab 1 login A tạo mã; Tab 2 login B nhập mã | Cả hai thấy Couple Home với 2 thành viên | |
| Couple Home | Xem thông tin cặp đôi | Đúng tên "Bạn và <partner>", trạng thái, ngày kỷ niệm | |
| Hủy ghép đôi | Bấm Hủy ghép đôi → "Ở lại" | Hộp thoại đóng, vẫn ở Couple Home | |
| Hủy ghép đôi (xác nhận) | Bấm Hủy ghép đôi → "Hủy ghép đôi" | Quay về màn Pairing | |
| Loading/Empty/Error | Mở màn khi mạng chậm/mất mạng | Có spinner, có trạng thái lỗi + nút Thử lại | |

### Sprint 2

| Chức năng | Bước test | Kết quả mong đợi | Pass/Fail |
|---|---|---|---|
| Skeleton | Mở Timeline | Hiện skeleton giữ bố cục, sau đó là danh sách ảnh | |
| Infinite scroll | Cuộn xuống cuối danh sách | Tự nạp thêm trang; hết dữ liệu hiện "Bạn đã xem hết ảnh rồi." | |
| Pull-to-refresh | Kéo xuống ở đầu danh sách | Làm mới, giữ đúng trang đầu | |
| Empty | Timeline không có ảnh | "Chưa có ảnh nào. Hãy gửi tấm ảnh đầu tiên cho người ấy!" | |
| Error | Giả lập lỗi tải (403) | "Bạn không có quyền xem nội dung này." + nút Thử lại | |
| Photo detail | Chạm một ảnh | Ảnh, người gửi, thời gian hiển thị **theo giờ local** (dd/MM/yyyy HH:mm) | |
| Reaction (thêm) | Chạm ❤️ | Số đếm tăng ngay (optimistic), không giật | |
| Reaction (đổi/bỏ) | Chạm 👍 rồi chạm lại 👍 | Đổi sang 👍, chạm lại thì bỏ reaction | |
| Reaction (rollback) | Giả lập lỗi reaction | Số đếm trở về cũ + SnackBar báo lỗi | |
| Quyền riêng tư | Xem ảnh không thuộc couple (403/404) | Thông báo gọn gàng, không lộ URL công khai | |

## 9. Vị trí chụp screenshot (đề xuất)

Lưu vào `docs/design/m2/` (tạo khi chụp), đặt tên theo màn — dùng cho slide báo cáo:

| # | Tên file | Màn hình |
|---|---|---|
| 1 | `m2-01-login.png` | Login (chế độ mock) |
| 2 | `m2-02-pairing.png` | Pairing (nút Tạo mã / Nhập mã) |
| 3 | `m2-03-create-invite.png` | Tạo mã mời (mã + hạn + Sao chép/Chia sẻ) |
| 4 | `m2-04-join-invite-error.png` | Nhập mã kèm lỗi (ví dụ `EXPYR3`) |
| 5 | `m2-05-couple-home.png` | Couple Home + dialog "Hủy ghép đôi?" |
| 6 | `m2-06-timeline-skeleton.png` | Timeline đang tải (skeleton) |
| 7 | `m2-07-timeline-list.png` | Timeline danh sách ảnh + reaction |
| 8 | `m2-08-photo-detail.png` | Chi tiết ảnh (giờ local, reaction) |
| 9 | `m2-09-timeline-empty.png` | Timeline rỗng |
| 10 | `m2-10-timeline-error.png` | Timeline lỗi + nút Thử lại |

## 10. Hướng dẫn chạy

**Chung:** cài Flutter SDK, tại `mobile/`:
```bash
flutter pub get
```

**Flutter Web (test/demo, khuyến nghị — dùng mock):**
```bash
flutter run -d chrome --dart-define=USE_MOCK=true
```

**iOS Simulator (mock):**
```bash
flutter run -d iphone --dart-define=USE_MOCK=true
# hoặc: mở Simulator rồi `flutter run` và chọn thiết bị iOS
```

**iOS Simulator (backend thật):** chạy Docker Compose ở gốc repo, bỏ flag mock:
```bash
flutter run -d iphone
# base URL mặc định http://localhost:8080
```
Máy thật/HTTPS: `--dart-define=OURSPACE_API_BASE_URL=https://...`.

**Tài khoản demo (mock):** `alex@ourspace.dev` / `sam@ourspace.dev`, mật khẩu `Password123!`.

**Kiểm thử chất lượng:**
```bash
flutter analyze
flutter test
```

## 11. Thay đổi cấu hình iOS

**Không có.** Trong phạm vi M2 không sửa `ios/Runner/Info.plist` hay deployment target. App dùng `http://localhost:8080` cho Simulator; `Info.plist` của M1 đã có `NSAppTransportSecurity → NSAllowsLocalNetworking` nên HTTP local chạy được. Push (Firebase/APNs) giữ nguyên như M1, và **được bỏ qua trên Web** để `flutter run -d chrome` khởi động được (`core/push` có bản stub cho web).

Lưu ý: `analysis_options.yaml` được công cụ Flutter tự thêm `analyzer.exclude: [build/**, ios/**]` khi chạy `pub get` (tránh phân tích thư mục sinh tự động) — không phải thay đổi cấu hình iOS.

## 12. Khó khăn & cách giải quyết

1. **Không dùng `dart:io` để chạy được cả Web.** `core/push` tách thành `app_push_bridge.dart` (abstract) + `push_bridge_factory.dart` (chọn theo `dart.library.io`) + `push_bridge_stub.dart` (web) / `push_bridge_io.dart` (iOS). `main.dart` chỉ import bản factory nên không kéo `dart:io`.
2. **Token storage trên Web không có Keychain.** `SecureTokenStorage` ưu tiên `flutter_secure_storage` (iOS Keychain) và có `InMemoryTokenStorage` dự phòng an toàn cho web.
3. **`testWidgets` chạy trên fake-async.** `await` repository mock (`Future.delayed`) **trước** `pump` sẽ treo vì timer không được chạy. Khắc phục: pre-pair dữ liệu trong `tester.runAsync(...)`; ở test skeleton phải `pump(Duration)` vượt độ trễ rồi mới `pumpAndSettle()`.
4. **Widget nằm dưới màn hình không tap được.** Reaction bar của thẻ ảnh đầu tiên rơi xuống ngoài viewport (~y=740 > 600). Khắc phục: gọi `tester.ensureVisible(...)` trước khi `tap`.
5. **Ảnh riêng tư & lints mới.** Dùng `imagePath` có xác thực + cache theo `imagePath`; sửa các lint/error của Dart 3.13 (`use_null_aware_elements`, `unnecessary_import`, `missing_function_body`, thiếu import `kIsWeb`) để `flutter analyze` sạch.
6. **Response lỗi không đồng nhất giữa các module.** Pairing dùng `message` tiếng Việt từ server, auth trả tiếng Anh — nên `ApiException.userMessage` map theo `code` và fallback về `message`.

## 13. Việc chưa làm / phụ thuộc

- Backend thật cho timeline/reaction: các endpoint `GET /api/v1/photos`, `GET /api/v1/photos/{id}`, `PUT/DELETE .../reaction` là **contract đề xuất** (M2) — chưa xác nhận đã có trên backend, nên demo dùng mock. Khi backend sẵn sàng chỉ cần bỏ `--dart-define=USE_MOCK=true`.
- Test 2 thiết bị thật (iOS): checklist §8 đã chuẩn bị; cần chạy thủ công trên 2 máy/tài khoản khi có APNs + backend.
- Firebase/APNs: giữ nguyên phần M1, cần cấu hình + máy thật để kiểm thử push.
