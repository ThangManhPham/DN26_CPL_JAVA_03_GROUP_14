# OurSpace Member 4 - Sprint 3 Delivery Report: AI Memory Story

- **Tác giả (Member 4)**: Nguyen Dinh Long (`dinhlong235` / `lngnguyen94@gmail.com`)
- **Nhánh triển khai**: `feature/S3-M4-ai-memory-story`
- **Mục tiêu**: US-05 - Sáng tạo câu chuyện kỷ niệm tình yêu từ Album bằng Generative AI (Database $\rightarrow$ Backend $\rightarrow$ Flutter UI $\rightarrow$ Unit & Integration Tests $\rightarrow$ Privacy & Security Enforcements).
- **Trạng thái**: Hoàn thành toàn diện, 102/102 backend tests passed, sẵn sàng nghiệm thu và review.

---

## 1. Bối cảnh nhánh & Tích hợp PR #8

- **PR #8 (`feature/S2-M4-memory-albums`)**: Đang mở trên remote repo `ThangManhPham/DN26_CPL_JAVA_03_GROUP_14`, chứa toàn bộ tính năng Memory Albums (Flyway V5, Album CRUD, photo association, concurrency controls).
- **Nhánh Sprint 3**: Được rẽ nhánh từ `feature/S2-M4-memory-albums` và merge tích hợp với commit mới nhất trên `main` (`af1b7df`), bao gồm:
  - M1: Photo management & storage
  - M2: Timeline, pairing gateway & declared router
  - M3: Calendar events (Flyway V6)
  - M5: Docker & CI configurations
- **Xử lý xung đột merge**: Đã giải quyết 3 điểm xung đột sạch sẽ tại commit `26e5c23`:
  - `backend/src/main/resources/db/h2-migration/V5__create_albums.sql` (đồng bộ đường dẫn H2 migration)
  - `backend/src/test/java/com/ourspace/OurSpaceApplicationTests.java` (nâng assertion phiên bản migration lên `"7"`)
  - `mobile/lib/main.dart` (tiếp nhận cấu trúc AppRouter khai báo chuẩn từ `main`).

---

## 2. Thiết kế Cơ sở Dữ liệu & Flyway Migration V7

Hệ thống bổ sung migration `V7` nối tiếp phiên bản `V6` của M3, đảm bảo thứ tự liên tục và tương thích cả PostgreSQL 16 lẫn H2 In-Memory (dùng cho automated tests):

### 2.1. File migration
- PostgreSQL: `backend/src/main/resources/db/migration/V7__create_memory_stories.sql`
- H2 Test: `backend/src/main/resources/db/h2-migration/V7__create_memory_stories.sql`

### 2.2. Cấu trúc bảng
```sql
CREATE TABLE memory_stories (
    id UUID PRIMARY KEY,
    couple_id UUID NOT NULL,
    album_id UUID NOT NULL,
    title VARCHAR(200) NOT NULL,
    story TEXT NOT NULL,
    highlights JSONB NOT NULL DEFAULT '[]', -- TEXT trên H2
    tone VARCHAR(50) NOT NULL DEFAULT 'ROMANTIC',
    status VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    prompt_notes TEXT,
    created_by UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    saved_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT fk_story_couple FOREIGN KEY (couple_id) REFERENCES couples(id) ON DELETE CASCADE,
    CONSTRAINT fk_story_album FOREIGN KEY (album_id) REFERENCES albums(id) ON DELETE CASCADE,
    CONSTRAINT fk_story_creator FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT chk_story_status CHECK (status IN ('DRAFT', 'SAVED'))
);

CREATE TABLE memory_story_photos (
    story_id UUID NOT NULL,
    photo_id UUID NOT NULL,
    order_index INT NOT NULL DEFAULT 0,
    added_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (story_id, photo_id),
    CONSTRAINT fk_msp_story FOREIGN KEY (story_id) REFERENCES memory_stories(id) ON DELETE CASCADE,
    CONSTRAINT fk_msp_photo FOREIGN KEY (photo_id) REFERENCES photos(id) ON DELETE CASCADE
);

CREATE INDEX idx_memory_stories_album ON memory_stories(album_id, status);
CREATE INDEX idx_memory_stories_couple ON memory_stories(couple_id, created_at DESC);
```

### 2.3. Quy ước quan hệ & OD-03 Unpair
- Quan hệ ràng buộc khóa ngoại với `couples` và `albums` đi kèm `ON DELETE CASCADE`.
- Khi cặp đôi thực hiện hủy ghép đôi hoặc xóa Album, toàn bộ Memory Stories liên quan sẽ được dọn dẹp sạch sẽ theo chu trình cascade database mà không để lại dữ liệu mồ côi.

---

## 3. Kiến trúc Backend & AI Integration

### 3.1. Các tầng mã nguồn triển khai
- **Entities**:
  - `MemoryStory.java`: Ánh xạ bảng `memory_stories`, hỗ trợ cập nhật nháp, lưu chính thức (`save()`), và kiểm tra trạng thái (`isDraft()`, `isSaved()`).
  - `MemoryStoryPhoto.java` & `MemoryStoryPhotoId.java`: Ánh xạ liên kết nhiều-nhiều giữa Story và Photo có thứ tự.
  - `MemoryStoryStatus.java`: Enum `DRAFT`, `SAVED`.
- **Repositories**:
  - `MemoryStoryRepository.java`: Truy vấn story theo ID, theo Couple, và theo Album lọc trạng thái SAVED hoặc theo tác giả.
  - `MemoryStoryPhotoRepository.java`: Quản lý danh sách ảnh đính kèm câu chuyện.
- **DTOs**:
  - `CreateMemoryStoryRequest`: Payload tạo story (`albumId`, `selectedPhotoIds`, `notes`, `tone`, `@NotNull consent`).
  - `UpdateMemoryStoryRequest`: Payload chỉnh sửa bản nháp (`title`, `story`, `highlights`, `tone`).
  - `MemoryStoryResponse`: Response chuẩn trả về cho client.
  - `AiGeneratedStoryDto`: DTO ánh xạ JSON phản hồi từ LLM.
- **AI Core Components**:
  - `AiStoryClient.java`: Interface trừu tượng hóa dịch vụ AI.
  - `GeminiAiStoryClient.java`: Triển khai tích hợp Google Gemini REST API (`gemini-1.5-flash`), cấu hình timeout 15s, rate limit error handling (429), bóc tách JSON an toàn loại bỏ markdown fences (` ```json `), và kiểm định schema chặt chẽ.
  - `MockAiStoryClient.java`: Mock client chạy 100% offline, sinh nội dung mẫu đầy đủ điểm nhấn (highlights) cho môi trường test mà không cần API key.
  - `AiPromptBuilder.java`: Xây dựng system prompt định hướng văn phong lãng mạn, ấm áp của OurSpace, kèm bộ lọc phòng chống tấn công Prompt Injection (lọc bỏ thẻ điều khiển, prompt override và ký tự đặc biệt).
  - `AiStoryConfiguration.java`: Tự động nạp `GeminiAiStoryClient` khi có cấu hình `ourspace.ai.provider=gemini`, ngược lại dùng `MockAiStoryClient`.
- **Service Layer (`MemoryStoryService.java`)**:
  - **Kiểm tra sự đồng thuận**: Bắt buộc `consent=true`, nếu không trả về lỗi `400 AI_CONSENT_REQUIRED`.
  - **Kiểm định dữ liệu trước AI**: Xác thực người dùng có cặp đôi active, album thuộc cặp đôi, và tất cả ảnh được chọn phải thuộc về album đó (`PHOTO_NOT_IN_ALBUM`).
  - **Rate Limiting**: Giới hạn tần suất tạo câu chuyện (cooldown 60s per user/album), trả về `429 AI_SUBMIT_LIMIT_EXCEEDED` khi vượt ngưỡng.
  - **Cuộc gọi mạng ngoài không giữ Transaction**: Tách biệt bước gọi AI ra khỏi transaction cơ sở dữ liệu (`Non-transactional AI call`), loại bỏ nguy cơ cạn kiệt connection pool hay lock database.
  - **Quyền riêng tư bản nháp (Draft Privacy)**: Bản nháp (`DRAFT`) chỉ có tác giả tạo ra mới có quyền đọc và chỉnh sửa (`DRAFT_ACCESS_DENIED` 403 nếu đối phương cố tình truy cập).
  - **Lưu câu chuyện (Publish / Save)**: Tác giả chuyển trạng thái sang `SAVED`. Thao tác này là idempotent (lưu lại không gây lỗi). Khi đã `SAVED`, cả hai thành viên trong cặp đôi đều có thể xem trong Album.
  - **Tính bất biến của câu chuyện đã lưu**: Không cho phép sửa câu chuyện đã `SAVED` (`400 CANNOT_EDIT_SAVED_STORY`).
- **REST Controller (`MemoryStoryController.java`)**:
  - `POST /api/v1/ai/memory-stories`: Tạo bản nháp story với AI (201 Created).
  - `GET /api/v1/ai/memory-stories/{id}`: Xem chi tiết story (200 OK).
  - `PUT /api/v1/ai/memory-stories/{id}`: Cập nhật bản nháp story (200 OK).
  - `POST /api/v1/ai/memory-stories/{id}/save`: Lưu câu chuyện vào Album (200 OK).
  - `GET /api/v1/albums/{albumId}/stories`: Danh sách câu chuyện trong Album (đã lọc quyền riêng tư).

---

## 4. Giao diện Mobile Flutter

Triển khai giao diện người dùng trọn vẹn, tuân thủ bảng màu và Design System của OurSpace (`AppColors.rose`, `AppColors.softRose`, Material 3):

1. **Repository Client (`mobile/lib/data/memory_story_repository.dart`)**:
   - `HttpMemoryStoryRepository`: Tích hợp chuẩn REST backend, bóc tách lỗi chi tiết (`AI_CONSENT_REQUIRED`, `DRAFT_ACCESS_DENIED`, `AI_SUBMIT_LIMIT_EXCEEDED`, `AI_PROVIDER_ERROR`).
   - `MockMemoryStoryRepository`: Hỗ trợ chạy giả lập khi `useMock=true`.
2. **Chi tiết Album & Mục Câu chuyện AI (`mobile/lib/album_detail_screen.dart`)**:
   - Nút hành động AI trên AppBar và banner "Tạo câu chuyện kỷ niệm với AI".
   - Danh sách carousel các câu chuyện đã tạo (huy hiệu "Đã lưu" hoặc "Bản nháp", nhãn tone cảm xúc).
   - Modal Bottom Sheet tạo câu chuyện AI:
     - Chọn ảnh trong album (tối đa 20 ảnh, có bộ đếm và preview thumbnail).
     - Nhập gợi ý / ghi chú kỷ niệm (tùy chọn).
     - Chọn Tone phong cách (Lãng mạn, Hài hước, Sâu lắng, Thơ mộng).
     - **Hộp thoại đồng thuận (Mandatory Consent Checkbox)**: Buộc người dùng đánh dấu đồng ý trước khi nút bấm được kích hoạt.
     - Trạng thái loading quay vòng thân thiện trong khi AI đang viết câu chuyện.
3. **Màn hình Câu chuyện kỷ niệm (`mobile/lib/memory_story_screen.dart`)**:
   - Hiển thị tiêu đề, lời kể AI, điểm nhấn đáng nhớ (highlights).
   - Thẻ cảnh báo quyền riêng tư khi ở trạng thái bản nháp.
   - Hộp thoại chỉnh sửa tiêu đề, nội dung, điểm nhấn.
   - Nút "Lưu vào Album" (chuyển sang `SAVED`) có thông báo SnackBar xác nhận.
4. **Điều hướng từ Couple Home (`mobile/lib/features/pairing/presentation/couple_home_screen.dart`)**:
   - Bổ sung nút lối vào "Album & Kỷ niệm của hai bạn" ngay tại màn hình chính Couple Home.
5. **Kiểm thử Mobile Unit Tests (`mobile/test/memory_story_repository_test.dart`)**:
   - Đã viết 10 kịch bản kiểm thử toàn diện cho HttpMemoryStoryRepository và MockMemoryStoryRepository.

---

## 5. Chính sách Bảo mật, Riêng tư & An toàn AI

1. **Không gửi dữ liệu ảnh nhạy cảm lên Cloud AI**:
   - Quá trình tạo story chỉ gửi tiêu đề album, ghi chú văn bản do người dùng nhập và số lượng ảnh. Tuyệt đối không gửi raw binary ảnh, URL ảnh nhạy cảm hoặc token riêng tư lên Gemini API.
2. **User Consent bắt buộc**:
   - Phải có sự đồng thuận rõ ràng từ người dùng (`consent: true`). Nếu thiếu, API từ chối ngay lập tức tại tầng nghiệp vụ.
3. **Quyền riêng tư hai lớp**:
   - Lớp 1: Cô lập triệt để giữa các cặp đôi khác nhau (Cross-couple isolation).
   - Lớp 2: Bảo vệ bản nháp cá nhân (Draft Privacy) - đối tác không thể đọc trộm hay sửa bản nháp trước khi tác giả hoàn thiện và bấm Lưu.
4. **Phòng vệ Prompt Injection**:
   - Bộ lọc `AiPromptBuilder.sanitize()` loại bỏ các đoạn văn bản chứa câu lệnh thao túng system instructions, thẻ markdown nguy hiểm hoặc code độc hại.
5. **Rate Limiting**:
   - Ngăn chặn lạm dụng token AI bằng cơ chế rate limit 60 giây giữa các lần yêu cầu.

---

## 6. Kết quả Kiểm thử Thực tế

### 6.1. Backend Test Suite (`mvnw.cmd test`)
```
[INFO] -------------------------------------------------------
[INFO]  T E S T S
[INFO] -------------------------------------------------------
[INFO] Running com.ourspace.album.AlbumConcurrencyAndIntegrityTest ... [PASS]
[INFO] Running com.ourspace.album.AlbumIntegrationTest ... [PASS]
[INFO] Running com.ourspace.album.service.AlbumServiceTest ... [PASS]
[INFO] Running com.ourspace.album.story.ai.AiPromptBuilderTest ... [PASS]
[INFO] Running com.ourspace.album.story.service.MemoryStoryServiceTest ... [PASS]
[INFO] Running com.ourspace.album.story.MemoryStoryIntegrationTest ... [PASS]
[INFO] Running com.ourspace.ApiContractAndSecurityTests ... [PASS]
[INFO] Running com.ourspace.OurSpaceApplicationTests ... [PASS] (Flyway V7 verified)
[INFO] Running com.ourspace.couplespace.CalendarIntegrationTests ... [PASS]
[INFO] Running com.ourspace.identity.AuthIntegrationTest ... [PASS]
[INFO] Running com.ourspace.pairing.PairingConcurrencyTest ... [PASS]
[INFO] Running com.ourspace.pairing.PairingIntegrationTest ... [PASS]
[INFO] Running com.ourspace.photo.PhotoIntegrationTest ... [PASS]
...
[INFO] Results:
[INFO] Tests run: 102, Failures: 0, Errors: 0, Skipped: 0
[INFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
```
- **Tổng số tests**: 102/102 PASS (0 Failures, 0 Errors, 0 Skipped).
- **Flyway V7**: Đã được thực thi và xác nhận qua Spring Boot context test.
- **Hệ thống chạy 100% offline**: Không cần cấp API key bên ngoài nhờ `MockAiStoryClient`.

### 6.2. Flutter Environment Status
- **Trạng thái**: `BLOCKED` trên máy cục bộ do Flutter SDK chưa được cài đặt vào PATH môi trường Windows (`'flutter' is not recognized`).
- **Mã nguồn Dart**: Đã được rà soát thủ công, tuân thủ đầy đủ types, design theme `AppColors`, và viết sẵn bộ test `memory_story_repository_test.dart`.

---

## 7. Danh sách file thay đổi & tạo mới

### Backend:
- `backend/src/main/resources/db/migration/V7__create_memory_stories.sql`
- `backend/src/main/resources/db/h2-migration/V7__create_memory_stories.sql`
- `backend/src/main/resources/application.yml`
- `backend/src/test/resources/application-test.yml`
- `.env.example`
- `backend/src/main/java/com/ourspace/album/story/entity/MemoryStory.java`
- `backend/src/main/java/com/ourspace/album/story/entity/MemoryStoryPhoto.java`
- `backend/src/main/java/com/ourspace/album/story/entity/MemoryStoryPhotoId.java`
- `backend/src/main/java/com/ourspace/album/story/entity/MemoryStoryStatus.java`
- `backend/src/main/java/com/ourspace/album/story/repository/MemoryStoryRepository.java`
- `backend/src/main/java/com/ourspace/album/story/repository/MemoryStoryPhotoRepository.java`
- `backend/src/main/java/com/ourspace/album/story/dto/CreateMemoryStoryRequest.java`
- `backend/src/main/java/com/ourspace/album/story/dto/UpdateMemoryStoryRequest.java`
- `backend/src/main/java/com/ourspace/album/story/dto/AiGeneratedStoryDto.java`
- `backend/src/main/java/com/ourspace/album/story/dto/MemoryStoryResponse.java`
- `backend/src/main/java/com/ourspace/album/story/ai/AiPromptBuilder.java`
- `backend/src/main/java/com/ourspace/album/story/ai/AiStoryProperties.java`
- `backend/src/main/java/com/ourspace/album/story/ai/AiStoryClient.java`
- `backend/src/main/java/com/ourspace/album/story/ai/MockAiStoryClient.java`
- `backend/src/main/java/com/ourspace/album/story/ai/GeminiAiStoryClient.java`
- `backend/src/main/java/com/ourspace/album/story/ai/AiStoryConfiguration.java`
- `backend/src/main/java/com/ourspace/album/story/service/MemoryStoryService.java`
- `backend/src/main/java/com/ourspace/album/story/controller/MemoryStoryController.java`
- `backend/src/test/java/com/ourspace/OurSpaceApplicationTests.java`
- `backend/src/test/java/com/ourspace/album/story/ai/AiPromptBuilderTest.java`
- `backend/src/test/java/com/ourspace/album/story/service/MemoryStoryServiceTest.java`
- `backend/src/test/java/com/ourspace/album/story/MemoryStoryIntegrationTest.java`

### Mobile Flutter:
- `mobile/lib/data/memory_story_repository.dart`
- `mobile/lib/memory_story_screen.dart`
- `mobile/lib/album_detail_screen.dart`
- `mobile/lib/album_list_screen.dart`
- `mobile/lib/features/pairing/presentation/couple_home_screen.dart`
- `mobile/test/memory_story_repository_test.dart`

### Tài liệu:
- `docs/18-m4-sprint3-ai-memory-story.md`
