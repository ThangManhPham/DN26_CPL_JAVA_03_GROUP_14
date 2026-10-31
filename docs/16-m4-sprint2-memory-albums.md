# Báo Cáo Kỹ Thuật Sprint 2: Memory Albums (Member 4)

**Dự án:** OurSpace – Couple App  
**Thành viên:** Member 4 (Senior Full-Stack & Database Architect)  
**Nhánh tính năng:** `feature/S2-M4-memory-albums`  
**Trạng thái:** Hoàn thành & Sẵn sàng bàn giao  

---

## 1. Tổng Quan Tính Năng (Feature Scope)
Trong Sprint 2, Member 4 chịu trách nhiệm triển khai toàn trình (Vertical Slice: Database -> Backend Spring Boot -> Security -> REST API -> Flutter Mobile -> Automated Tests -> Documentation) cho tính năng **Memory Albums (Album Kỷ Niệm)**:
- Cho phép hai người dùng trong cùng một cặp đôi (`ACTIVE` couple) tạo các album chủ đề (ví dụ: Chuyến đi Đà Lạt, Kỷ niệm 1 năm...).
- Xem danh sách album kèm ảnh bìa, số lượng ảnh và ngày tạo.
- Xem chi tiết từng album và danh sách ảnh kỷ niệm đã đưa vào album theo thứ tự mới nhất.
- Thêm ảnh có sẵn từ thư viện ảnh của cặp đôi vào album.
- Bỏ liên kết ảnh khỏi album (ảnh gốc trong thư viện `photos` vẫn được bảo toàn nguyên vẹn).
- Cập nhật thông tin album (tiêu đề, mô tả, ảnh bìa).
- Xóa album (chỉ xóa cấu trúc album và bảng liên kết `album_photos`, tuyệt đối không xóa ảnh vật lý/ảnh gốc).
- **Ranh giới phạm vi (Scope Boundary):**
  - Không sinh AI Story trong Sprint 2 (hoãn sang Sprint 3 theo roadmap).
  - Không triển khai upload pipeline mới (tận dụng trọn vẹn photo pipeline do Member 1 phát triển).
  - Endpoint giải tán cặp đôi (`DELETE /api/v1/couples/me`) tiếp tục giữ trạng thái chờ quyết định nghiệp vụ (`501 UNPAIRING_POLICY_PENDING` theo OD-03).

---

## 2. Thiết Kế Cơ Sở Dữ Liệu & Flyway Migrations (S2-DB)

### 2.1. Migration Version `V5`
Tuân thủ nguyên tắc di trú gia tăng additive, không sửa đổi các migration đã chạy (`V1` - `V4`, `R`):
- `backend/src/main/resources/db/migration/V5__create_albums.sql` (PostgreSQL)
- `backend/src/test/resources/db/h2-migration/V5__create_albums.sql` (H2 in-memory test)

```sql
CREATE TABLE albums (
    id UUID PRIMARY KEY,
    couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    title VARCHAR(100) NOT NULL,
    description VARCHAR(500),
    cover_photo_id UUID REFERENCES photos(id) ON DELETE SET NULL,
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE album_photos (
    album_id UUID NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
    photo_id UUID NOT NULL REFERENCES photos(id) ON DELETE CASCADE,
    added_at TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (album_id, photo_id)
);

CREATE INDEX idx_albums_couple_created ON albums(couple_id, created_at DESC);
CREATE INDEX idx_album_photos_album_added ON album_photos(album_id, added_at DESC);
CREATE INDEX idx_album_photos_photo_id ON album_photos(photo_id);
```

### 2.2. Ràng Buộc & Tính Toàn Vẹn Dữ Liệu
1. **Khóa chính UUID & Khóa ngoại liên kết chặt chẽ**:
   - `couple_id REFERENCES couples(id) ON DELETE CASCADE`: Khi cặp đôi bị xóa, tất cả album liên quan sẽ được dọn dẹp an toàn.
   - `cover_photo_id REFERENCES photos(id) ON DELETE SET NULL`: Nếu ảnh bìa bị xóa khỏi thư viện, thuộc tính ảnh bìa album chuyển về `NULL` mà không làm hỏng album.
   - `created_by REFERENCES users(id)`: Lưu vết người tạo album.
2. **Khóa chính phức hợp trên bảng liên kết (`PRIMARY KEY (album_id, photo_id)`)**:
   - Chống trùng lặp tuyệt đối ở mức cơ sở dữ liệu (idempotent / ngăn duplicate photo association).
3. **Chỉ mục truy vấn (Indexes)**:
   - `idx_albums_couple_created`: Tối ưu hóa truy vấn danh sách album của cặp đôi theo thứ tự thời gian giảm dần.
   - `idx_album_photos_album_added`: Tối ưu hóa nạp danh sách ảnh trong album theo thứ tự thêm mới nhất.
   - `idx_album_photos_photo_id`: Tối ưu hóa truy vấn ngược để kiểm tra ảnh thuộc những album nào.

---

## 3. Kiến Trúc Backend Spring Boot (`com.ourspace.album`)

### 3.1. Phân Lớp Mô-đun Monolith (Package Structure)
```
backend/src/main/java/com/ourspace/album/
├── controller/
│   └── AlbumController.java         # REST endpoints bảo mật với JWT Bearer
├── dto/
│   ├── CreateAlbumRequest.java      # Validation tiêu đề (@NotBlank, @Size(max=100))
│   ├── UpdateAlbumRequest.java      # Cập nhật thông tin album
│   ├── AlbumResponse.java           # DTO tóm tắt danh sách album & photoCount
│   └── AlbumDetailResponse.java     # DTO chi tiết album kèm List<PhotoResponse>
├── entity/
│   ├── Album.java                   # JPA Entity đại diện bảng albums
│   ├── AlbumPhoto.java              # JPA Entity đại diện bảng liên kết album_photos
│   └── AlbumPhotoId.java            # Khóa chính nhúng (@Embeddable)
├── repository/
│   ├── AlbumRepository.java         # Truy vấn album theo coupleId & id
│   └── AlbumPhotoRepository.java    # Đếm số lượng, kiểm tra tồn tại và xóa liên kết
└── service/
    └── AlbumService.java            # Nghiệp vụ album, kiểm tra quyền sở hữu cặp đôi
```

### 3.2. REST API Endpoints Contract
Tất cả endpoint yêu cầu header `Authorization: Bearer <jwt_token>`:

| Method | Path | Request Body | Response Status & Body | Mô tả |
|---|---|---|---|---|
| `POST` | `/api/v1/albums` | `CreateAlbumRequest` (title, description, coverPhotoId) | `201 CREATED` + `AlbumResponse` | Tạo album mới |
| `GET` | `/api/v1/albums` | Không | `200 OK` + `List<AlbumResponse>` | Danh sách album của cặp đôi |
| `GET` | `/api/v1/albums/{id}` | Không | `200 OK` + `AlbumDetailResponse` | Chi tiết album & danh sách ảnh |
| `PUT` | `/api/v1/albums/{id}/photos/{photoId}` | Không | `200 OK` + `AlbumResponse` | Thêm ảnh vào album (tự set cover nếu trống) |
| `DELETE` | `/api/v1/albums/{id}/photos/{photoId}` | Không | `200 OK` + `AlbumResponse` | Bỏ ảnh khỏi album (ảnh gốc giữ nguyên) |
| `PUT` | `/api/v1/albums/{id}` | `UpdateAlbumRequest` | `200 OK` + `AlbumResponse` | Sửa tiêu đề, mô tả, ảnh bìa |
| `DELETE` | `/api/v1/albums/{id}` | Không | `204 NO CONTENT` | Xóa album (ảnh gốc giữ nguyên) |
| `GET` | `/api/v1/albums/available-photos` | Không | `200 OK` + `List<PhotoResponse>` | Lấy ảnh của cặp đôi để người dùng chọn |

---

## 4. Bảo Mật & Cô Lập Dữ Liệu (Security & Couple Isolation)
1. **Tuyệt đối không tin tưởng client-provided coupleId**:
   - `coupleId` được trích xuất hoàn toàn ở tầng server từ JWT Security Context thông qua `SecurityUtils.resolveUserId(auth)` và `coupleRepository.findActiveCoupleByUserId(userId)`.
2. **Kiểm tra trạng thái ghép đôi (Active Couple Check)**:
   - Người dùng chưa ghép đôi hoặc đã chia tay bị từ chối với `403 FORBIDDEN` (`NO_ACTIVE_COUPLE`).
3. **Cô lập dữ liệu giữa các cặp đôi (Cross-Couple Isolation)**:
   - Truy vấn album sử dụng `findByIdAndCoupleId(albumId, coupleId)`. Nếu người ngoài cố truy cập album của cặp đôi khác, hệ thống trả về `404 NOT_FOUND` (`ALBUM_NOT_FOUND`) để không làm lộ sự tồn tại của tài nguyên.
4. **Ngăn chặn trộn lẫn ảnh giữa các cặp đôi (Cross-Couple Photo Rejection)**:
   - Khi thêm ảnh vào album hoặc đặt ảnh bìa, server xác thực `photo.getCoupleId().equals(couple.getId())`. Nếu ảnh thuộc cặp đôi khác, hệ thống ngay lập tức trả về `403 FORBIDDEN` (`CROSS_COUPLE_PHOTO`).
5. **Không lộ Storage Key / Object Storage URL**:
   - Ảnh trong album trả về authenticated image path `/api/v1/photos/{id}/image`.

---

## 5. Kiến Trúc Ứng Dụng Flutter Mobile (`mobile/lib`)

1. **Repository Pattern**:
   - `mobile/lib/data/album_repository.dart`: Khai báo giao diện trừu tượng `AlbumRepository`, triển khai `HttpAlbumRepository` kết nối REST API thực tế với kiểm tra lỗi chuẩn xác, và `MockAlbumRepository` phục vụ chạy độc lập offline / widget testing.
2. **Màn hình Danh sách Album (`mobile/lib/album_list_screen.dart`)**:
   - Hiển thị danh sách card album với ảnh bìa xác thực, số lượng ảnh, tiêu đề, mô tả.
   - Trạng thái trống (Empty State) thân thiện, kèm nút tạo album đầu tiên.
   - Hộp thoại tạo album mới với kiểm tra validation tiêu đề không để trống.
3. **Màn hình Chi tiết Album (`mobile/lib/album_detail_screen.dart`)**:
   - Lưới ảnh 2 cột với thumbnail bo góc đẹp mắt.
   - Nút "Thêm ảnh" mở modal bottom sheet hiển thị danh sách ảnh chung của cặp đôi để chọn.
   - Nút xoá ảnh khỏi album có hộp thoại xác nhận rõ ràng rằng ảnh gốc không bị mất.
   - Nút xoá album trên AppBar với cảnh báo an toàn.
4. **Tích hợp Luồng chính (`mobile/lib/main.dart`)**:
   - Thêm nút "Album kỷ niệm" tại `HomeScreen` để chuyển hướng mượt mà sang `AlbumListScreen`.

---

## 6. Kết Quả Kiểm Thử Tự Động (QA Test Report)

### 6.1. Backend Unit Tests (`AlbumServiceTest.java`)
- `createAlbum_success`: Kiểm tra tạo album thành công, số lượng ảnh ban đầu bằng 0.
- `createAlbum_noActiveCouple`: Kiểm tra chặn 403 `NO_ACTIVE_COUPLE` khi chưa ghép đôi.
- `createAlbum_crossCoupleCoverPhoto`: Kiểm tra chặn 403 `CROSS_COUPLE_PHOTO` khi dùng ảnh cặp đôi khác làm bìa.
- `addPhotoToAlbum_success`: Thêm ảnh thành công, tự động cập nhật cover photo khi chưa có.
- `addPhotoToAlbum_crossCoupleRejected`: Chặn thêm ảnh của cặp đôi khác vào album.
- `removePhotoFromAlbum_updatesCover`: Xóa ảnh khỏi album và cập nhật lại ảnh bìa phù hợp.
- `deleteAlbum_photosNotDeleted`: Xóa album chỉ xóa cấu trúc liên kết, ảnh trong `photoRepository` không bị xóa.

### 6.2. Backend Integration Tests (`AlbumIntegrationTest.java`)
- `unauthenticatedRequestReturns401`: Không có Bearer token trả về 401 `UNAUTHORIZED`.
- `userWithoutCoupleReturns403`: Người dùng chưa ghép đôi gọi API trả về 403 `NO_ACTIVE_COUPLE`.
- `validationErrorOnEmptyTitle`: Tiêu đề rỗng hoặc chứa khoảng trắng trả về 422 `VALIDATION_ERROR`.
- `fullAlbumLifecycleForCouple`: Luồng hoàn chỉnh: Tạo album -> Đối phương xem danh sách -> Thêm ảnh -> Xem chi tiết -> Sửa album -> Xóa ảnh -> Xóa album.
- `crossCoupleIsolation`: Người dùng cặp đôi 2 không thể truy cập album của cặp đôi 1 (`404 ALBUM_NOT_FOUND`), người dùng cặp đôi 1 không thể thêm ảnh của cặp đôi 2 (`403 CROSS_COUPLE_PHOTO`).

### 6.3. Flyway & Database Verification (`OurSpaceApplicationTests.java`)
- Xác nhận Flyway di trú thành công đến version `"5"` không có lỗi pending: `contextLoadsWithRealMigrations` PASSED.

### 6.4. Mobile Tests
- `mobile/test/album_repository_test.dart`: Kiểm thử serialization, header Bearer JWT, xử lý HTTP error status.
- `mobile/test/album_widget_test.dart`: Kiểm thử widget render `AlbumListScreen` (empty state, form dialog, card rendering) và `AlbumDetailScreen` (thêm ảnh từ sheet, hiển thị lưới ảnh, xác nhận xóa ảnh).
