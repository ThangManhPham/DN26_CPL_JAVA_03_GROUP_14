# Báo Cáo Kỹ Thuật Sprint 2: Memory Albums (Member 4)

**Dự án:** OurSpace – Couple App  
**Thành viên:** Member 4 (Senior Full-Stack & Database Architect)  
**Nhánh tính năng:** `feature/S2-M4-memory-albums`  
**Trạng thái:** Hoàn thành, Tối ưu hóa N+1 & Đạt chuẩn kiểm thử  

---

## 1. Tổng Quan Tính Năng (Feature Scope)
Trong Sprint 2, Member 4 chịu trách nhiệm triển khai toàn trình (Vertical Slice: Database -> Backend Spring Boot -> Security -> REST API -> Flutter Mobile -> Automated Tests -> Documentation) cho tính năng **Memory Albums (Album Kỷ Niệm)**:
- Cho phép hai người dùng trong cùng một cặp đôi (`ACTIVE` couple) tạo các album chủ đề (ví dụ: Chuyến đi Đà Lạt, Kỷ niệm 1 năm...).
- Xem danh sách album kèm ảnh bìa, số lượng ảnh và ngày tạo với hiệu năng tối ưu ($O(1)$ query roundtrips, không N+1).
- Xem chi tiết từng album và danh sách ảnh kỷ niệm đã đưa vào album theo thứ tự mới nhất.
- Thêm ảnh có sẵn từ thư viện ảnh của cặp đôi vào album.
- Bỏ liên kết ảnh khỏi album (ảnh gốc trong thư viện `photos` vẫn được bảo toàn nguyên vẹn).
- Cập nhật thông tin album (tiêu đề, mô tả, ảnh bìa). Đảm bảo ảnh bìa luôn thuộc về album.
- Xóa album (chỉ xóa cấu trúc album và bảng liên kết `album_photos`, tuyệt đối không xóa ảnh vật lý/ảnh gốc).
- **Ranh giới phạm vi (Scope Boundary):**
  - Không sinh AI Story trong Sprint 2 (hoãn sang Sprint 3 theo roadmap).
  - Không triển khai upload pipeline mới (tận dụng trọn vẹn photo pipeline do Member 1 phát triển).
  - Endpoint giải tán cặp đôi (`DELETE /api/v1/couples/me`) tiếp tục giữ trạng thái chờ quyết định nghiệp vụ (`501 UNPAIRING_POLICY_PENDING` theo OD-03).

---

## 2. Thiết Kế Cơ Sở Dữ Liệu & Toàn Vẹn Cùng Cặp Đôi (S2-DB & Integrity)

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

### 2.2. Phân Tích & Đề Xuất Toàn Vẹn Cùng Cặp Đôi Ở Mức Database (Same-Couple Integrity)
1. **Thực trạng**:
   - `album_photos` có 2 khóa ngoại độc lập `album_id -> albums(id)` và `photo_id -> photos(id)`.
   - `AlbumService` kiểm soát chặt chẽ ở tầng ứng dụng: `validatePhotoOwnership(photoId, couple.getId())`. Nếu ảnh không thuộc cặp đôi của album, hệ thống lập tức chặn bằng mã `403 FORBIDDEN` (`CROSS_COUPLE_PHOTO`).
2. **Khuyến nghị kỹ thuật mức PostgreSQL**:
   - *Phương án 1 (Composite FKs)*: Bổ sung cột `couple_id` vào `album_photos`, tạo ràng buộc `UNIQUE(id, couple_id)` trên cả `albums` và `photos`, sau đó tạo 2 composite foreign keys `(album_id, couple_id)` và `(photo_id, couple_id)`. Tuy nhiên, phương án này đòi hỏi thay đổi bảng `photos` của Member 1.
   - *Phương án 2 (PostgreSQL Trigger)*: Sử dụng trigger `BEFORE INSERT OR UPDATE ON album_photos` để xác nhận `(SELECT couple_id FROM albums WHERE id = NEW.album_id) = (SELECT couple_id FROM photos WHERE id = NEW.photo_id)`.
   - *Chính sách di trú*: Vì các thành viên khác đang làm việc trên Sprint 2 (M2, M3, M5), việc tự ý tạo migration `V6` sẽ gây xung đột phiên bản Flyway. Do đó, toàn vẹn được kiểm soát nghiêm ngặt ở Service + Primary Key phức hợp `(album_id, photo_id)`, và trigger PostgreSQL đã được chuẩn bị sẵn để tích hợp khi chốt phiên bản migration toàn đội.

---

## 3. Kiến Trúc Backend Spring Boot & Tối Ưu N+1 (`com.ourspace.album`)

### 3.1. Loại Bỏ Truy Vấn N+1 trong `listAlbums`
- **Trước tối ưu**: Với $N$ album, hệ thống thực hiện 1 truy vấn lấy danh sách album và $N$ truy vấn `countByIdAlbumId(album.getId())`.
- **Sau tối ưu**: `AlbumPhotoRepository` bổ sung truy vấn gom nhóm theo mảng ID:
  ```java
  @Query("SELECT ap.id.albumId, COUNT(ap.id.photoId) FROM AlbumPhoto ap " +
         "WHERE ap.id.albumId IN :albumIds GROUP BY ap.id.albumId")
  List<Object[]> countPhotosByAlbumIds(@Param("albumIds") Collection<UUID> albumIds);
  ```
  `AlbumService.listAlbums()` thực hiện ánh xạ kết quả vào `Map<UUID, Long>` trong đúng 1 truy vấn tổng hợp. Số lượng database query cố định là 2 ($O(1)$) bất kể số lượng album.

### 3.2. REST API Endpoints Contract
Tất cả endpoint yêu cầu header `Authorization: Bearer <jwt_token>`:

| Method | Path | Request Body | Response Status & Body | Mô tả |
|---|---|---|---|---|
| `POST` | `/api/v1/albums` | `CreateAlbumRequest` (title, description, coverPhotoId) | `201 CREATED` + `AlbumResponse` | Tạo album mới |
| `GET` | `/api/v1/albums` | Không | `200 OK` + `List<AlbumResponse>` | Danh sách album (truy vấn gom nhóm không N+1) |
| `GET` | `/api/v1/albums/{id}` | Không | `200 OK` + `AlbumDetailResponse` | Chi tiết album & danh sách ảnh |
| `PUT` | `/api/v1/albums/{id}/photos/{photoId}` | Không | `200 OK` + `AlbumResponse` | Thêm ảnh vào album (idempotent) |
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
4. **Bảo toàn ảnh gốc khi bỏ ảnh hoặc xóa album**:
   - Thao tác xóa album chỉ xóa bản ghi trong `albums` và `album_photos`. Bảng `photos` vật lý không bị đụng chạm.

---

## 5. Kiến Trúc Ứng Dụng Flutter Mobile (`mobile/lib`)
1. **Khởi tạo và kết nối API thực tế**:
   - Trong `mobile/lib/main.dart`, cờ `_mock` mặc định `false`, ứng dụng sử dụng `HttpAlbumRepository(baseUrl: _baseUrl)` kết nối trực tiếp đến backend.
2. **Xử lý phiên đăng nhập hết hạn (Session Expiry)**:
   - Khi máy chủ trả về `401 UNAUTHORIZED`, repository ném ngoại lệ thân thiện: `"Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại."`. Giao diện hiển thị SnackBar hoặc thông báo lỗi rõ ràng.
3. **Tải ảnh an toàn có xác thực**:
   - Tất cả ảnh và thumbnail hiển thị qua `photoRepository.image(token, photo)` gửi kèm header Bearer, không lộ S3 endpoint hay storageKey công khai.

---

## 6. Kết Quả Kiểm Thử QA Toàn Diện (QA Test Report)

Tổng số test Spring Boot thực thi qua `mvnw.cmd clean test`: **71 tests (100% PASSED, 0 FAILURES, 0 ERRORS)**.

### 6.1. Kiểm Thử Đồng Thời & Toàn Vẹn (`AlbumConcurrencyAndIntegrityTest.java`)
- `concurrentAddSamePhoto_idempotentNoDuplicates`: 10 luồng đồng thời thêm cùng 1 ảnh vào album -> Xử lý cạnh tranh an toàn dựa trên composite PK, đảm bảo đúng 1 bản ghi duy nhất được tạo.
- `concurrentAddDifferentPhotos_accurateCountsAndBatchList`: 10 luồng đồng thời thêm 10 ảnh khác nhau -> Đếm số lượng ảnh chính xác, truy vấn `listAlbums` gom nhóm thành công trong 1 query count duy nhất.
- `sameCoupleIntegrity_strictlyEnforced`: Chặn triệt để việc dùng ảnh của cặp đôi khác khi tạo album, thêm ảnh, hoặc sửa ảnh bìa.
- `coverPhotoIntegrity_lifecycleConsistency`: Ảnh bìa tự động thiết lập khi thêm ảnh đầu tiên; khi ảnh bìa bị xóa, tự động chỉ định ảnh tiếp theo làm bìa; khi album rỗng, ảnh bìa tự động đưa về null.

### 6.2. Kiểm Thử Nghiệp Vụ & Đơn Vị (`AlbumServiceTest.java`)
- Bổ sung `listAlbums_usesBatchCountQuery`: Kiểm tra phương thức chỉ gọi `countPhotosByAlbumIds` 1 lần duy nhất và không bao giờ gọi vòng lặp `countByIdAlbumId`.
- Kiểm tra toàn bộ luồng tạo, cập nhật bìa, xóa ảnh, xóa album.

### 6.3. Kiểm Thử Tích Hợp API & Bảo Mật (`AlbumIntegrationTest.java`)
- 5 kịch bản tích hợp MockMvc xác thực mã HTTP 401, 403, 404, 422 và 200/201/204.
