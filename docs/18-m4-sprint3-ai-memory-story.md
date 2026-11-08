# OurSpace Member 4 - Sprint 3 Delivery Report: AI Memory Story

- **Tác giả (Member 4)**: Nguyen Dinh Long (`dinhlong235` / `lngnguyen94@gmail.com`)
- **Nhánh triển khai**: `feature/S3-M4-ai-memory-story`
- **Mục tiêu**: US-05 - Sáng tạo câu chuyện kỷ niệm tình yêu từ Album bằng Generative AI (Database $\rightarrow$ Backend $\rightarrow$ Flutter UI $\rightarrow$ Concurrency & Transaction Hardening $\rightarrow$ Testing $\rightarrow$ Handover).
- **Trạng thái**: Hoàn thành toàn diện, 124/124 backend tests passed (H2), sẵn sàng nghiệm thu và review.

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
  - `backend/src/test/java/com/ourspace/OurSpaceApplicationTests.java` (nâng assertion phiên bản migration lên `"8"`)
  - `mobile/lib/main.dart` (tiếp nhận cấu trúc AppRouter khai báo chuẩn từ `main`).

---

## 2. Thiết kế Cơ sở Dữ liệu & Flyway Migration V7 & V8

Hệ thống bổ sung migration `V7` và `V8` nối tiếp phiên bản `V6` của M3, đảm bảo tính liên tục của chuỗi migration và tương thích cả PostgreSQL 16 lẫn H2 In-Memory:

### 2.1. File migration
- **V7 (Tạo bảng Memory Stories & Photos)**:
  - PostgreSQL: `backend/src/main/resources/db/migration/V7__create_memory_stories.sql`
  - H2 Test: `backend/src/main/resources/db/h2-migration/V7__create_memory_stories.sql`
- **V8 (Thêm cột Version hỗ trợ Optimistic Locking)**:
  - PostgreSQL: `backend/src/main/resources/db/migration/V8__add_memory_stories_version.sql`
  - H2 Test: `backend/src/main/resources/db/h2-migration/V8__add_memory_stories_version.sql`

### 2.2. Cấu trúc bảng và lược đồ
```sql
-- V7__create_memory_stories.sql
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

-- V8__add_memory_stories_version.sql
ALTER TABLE memory_stories ADD COLUMN version BIGINT NOT NULL DEFAULT 0;
```

### 2.3. Quy ước quan hệ & Chính sách Unpair OD-03
- **Ràng buộc khóa ngoại**: Đi kèm `ON DELETE CASCADE` trên `couples` và `albums` để đảm bảo toàn vẹn dữ liệu ở cấp cơ sở dữ liệu khi một entity cha bị xóa.
- **Chính sách Unpair OD-03**: Thao tác hủy ghép đôi (unpair) hiện đang bị chặn theo quy định nhóm (tạm ngưng chờ thống nhất chính sách lưu trữ / xóa dữ liệu OD-03). Member 4 tuyệt đối **không tự ý triển khai xóa dữ liệu người dùng** khi chính sách chưa được phê duyệt chính thức.

---

## 3. Kiến trúc Backend, AI Integration & Hardening

### 3.1. Phân định Transaction & Khắc phục Proxy Demarcation
- **Vấn đề đã khắc phục**: Phương thức `createStoryDraft` trước đây gọi phương thức lưu nháp trong cùng bean, khiến Spring AOP proxy bị bypass và không áp dụng được `@Transactional`.
- **Giải pháp**: Tách toàn bộ logic lưu trữ nguyên tử sang service riêng biệt: `MemoryStoryDraftPersistenceService`.
  - Service này sử dụng `TransactionTemplate` kết hợp `@Transactional` để đảm bảo lưu trữ Story cùng danh sách `memory_story_photos` một cách nguyên tử hoàn toàn. Nếu lưu bất kỳ ảnh nào thất bại, toàn bộ Story sẽ bị rollback tức thì.
  - **Lời gọi AI provider được thực hiện hoàn toàn ngoài transaction**: Đảm bảo thread không giữ kết nối cơ sở dữ liệu trong suốt thời gian chờ phản hồi mạng từ AI (tránh cạn kiệt Connection Pool HikariCP).
  - **Kiểm tra lại dữ liệu sau khi AI trả về (Post-AI re-checks)**: Khi nhận được kết quả từ AI, trước khi ghi dữ liệu, hệ thống xác thực lại: couple vẫn active, album vẫn tồn tại và thuộc couple, từng ảnh vẫn tồn tại và vẫn thuộc về album.

### 3.2. Giới hạn tần suất (Rate Limiting) & Chống Race Condition
- **Vấn đề đã khắc phục**: Việc đếm bản nháp DRAFT trong DB dễ bị lọt qua khi nhiều request gửi đồng thời hoặc khi bản nháp đã chuyển sang SAVED.
- **Giải pháp**: `AiStoryRateLimiter` quản lý giữ chỗ nguyên tử trong bộ nhớ (`ConcurrentHashMap.compute`):
  - **Giữ chỗ nguyên tử (Atomic Reservation)**: Ngay trước khi gọi provider, kiểm tra và giữ chỗ ngay lập tức cho `userId`.
  - **Giới hạn đồng thời**: Mỗi user chỉ được phép có tối đa 1 yêu cầu AI đang thực thi (`in-flight`).
  - **Cửa sổ Cooldown**: Sau khi tạo thành công, user phải chờ 60 giây trước khi có thể yêu cầu tạo câu chuyện mới.
  - **Xử lý lỗi**: Nếu cuộc gọi AI gặp sự cố (timeout, 429, lỗi mạng), slot giữ chỗ được giải phóng ngay lập tức để user có thể thử lại mà không bị phạt chờ cooldown.
  - **Từ chối**: Nếu vi phạm rate limit, hệ thống trả về HTTP 429 `AI_SUBMIT_LIMIT_EXCEEDED`.

### 3.3. Kiểm soát đồng thời khi Cập nhật và Lưu (Concurrency & Versioning)
- **Optimistic Locking**: Bổ sung trường `@Version private Long version = 0L;` trên `MemoryStory`. Mọi thay đổi qua `updateStoryDraft` và `saveStory` đều làm tăng version.
- **Pessimistic Lock**: Truy vấn `findByIdAndCoupleIdWithLock` sử dụng `@Lock(LockModeType.PESSIMISTIC_WRITE)` ngăn chặn race condition khi hai thao tác đồng thời cố tình cập nhật hoặc lưu cùng một bản ghi.
- **Bảo vệ tính toàn vẹn trạng thái**: Một khi câu chuyện đã chuyển sang `SAVED`, hệ thống từ chối mọi yêu cầu chỉnh sửa bằng HTTP 409 `STORY_ALREADY_SAVED`, ngăn chặn việc đưa câu chuyện đã duyệt về `DRAFT` hoặc ghi đè nội dung. Thao tác `saveStory` được thiết kế có tính Idempotent.

### 3.4. Mô hình Gemini & An toàn Bảo mật Lỗi
- **Cập nhật Model**: Chuyển mặc định sang `gemini-2.0-flash` (dòng mô hình chính thức, ổn định và hiệu năng cao của Google). Cho phép cấu hình linh hoạt qua biến môi trường `AI_MODEL` hoặc `ourspace.ai.model`.
- **Tách biệt Mock vs Production**:
  - `MockAiStoryClient`: Tự động kích hoạt trong môi trường kiểm thử tự động hoặc khi `ourspace.ai.provider=mock`, bảo đảm không gọi API bên ngoài hay phát sinh chi phí trong CI/CD.
  - `GeminiAiStoryClient`: Kích hoạt khi `ourspace.ai.provider=gemini` và có API key hợp lệ. Hỗ trợ inject `HttpClient` cho unit testing và cấu hình timeout.
- **Sanitized Error Logging**: Tuyệt đối không log URL chứa query parameter `?key=...` hoặc chi tiết ngoại lệ mạng có khả năng rò rỉ API key ra log máy chủ hoặc trả về client. Mã lỗi chuẩn hóa: `AI_TIMEOUT` (504), `AI_RATE_LIMIT` (429), `AI_PROVIDER_ERROR` (502), `AI_CALL_FAILED` (500).

### 3.5. Đồng bộ Contract `tone` & Strict JSON Validation
- Hệ thống hỗ trợ các tone: `ROMANTIC`, `HUMOROUS`, `POETIC`, `NOSTALGIC`.
- Đồng bộ hoàn toàn giữa Flutter UI, `CreateMemoryStoryRequest`, `UpdateMemoryStoryRequest`, `MemoryStoryService`, `AiPromptBuilder` và `GeminiAiStoryClient`.
- Đã kiểm thử với cấu hình Jackson nghiêm ngặt (`fail-on-unknown-properties: true`), bảo đảm payload gửi từ Flutter được backend chấp nhận chính xác.

### 3.6. Phòng vệ Prompt Injection & Kiểm định đầu ra AI
- **Phòng vệ theo chiều sâu (Defense in Depth)**: `AiPromptBuilder.sanitize()` lọc bỏ ký tự điều khiển, giới hạn độ dài, ngăn chặn các chuỗi override instructions phổ biến. Lưu ý: Đây là biện pháp giảm thiểu rủi ro theo chiều sâu, không thể xem là lá chắn tuyệt đối chống lại mọi kỹ thuật injection tinh vi.
- **Kiểm định đầu ra khắt khe (`parseGeminiResponse`)**:
  - Loại bỏ markdown code blocks (` ```json ... `).
  - Bắt buộc các trường `title` (1-200 ký tự), `story` (1-5000 ký tự).
  - `highlights` bắt buộc là mảng JSON (lấy 1-5 phần tử, mỗi phần tử tối đa 200 ký tự).
  - Phản hồi sai schema ném lỗi `402 AI_INVALID_RESPONSE`.

---

## 4. Giao diện Mobile Flutter

Triển khai giao diện theo đúng OurSpace Design System (`AppColors.rose`, `AppColors.softRose`, Material 3):

1. **Repository Client (`mobile/lib/data/memory_story_repository.dart`)**:
   - `HttpMemoryStoryRepository`: Tích hợp đầy đủ các mã lỗi HTTP 400, 401, 403, 404, 409 (`STORY_ALREADY_SAVED`), 429 (`AI_SUBMIT_LIMIT_EXCEEDED`), 502/503 (`AI_PROVIDER_ERROR`).
   - `MockMemoryStoryRepository`: Dùng cho chế độ offline/mock mode.
2. **Chi tiết Album & Tạo Story (`mobile/lib/album_detail_screen.dart`)**:
   - Nút hành động AI trên AppBar và banner "Tạo câu chuyện kỷ niệm với AI".
   - Danh sách carousel các câu chuyện đã tạo (huy hiệu "Đã lưu" hoặc "Bản nháp", nhãn tone cảm xúc).
   - Modal Bottom Sheet tạo câu chuyện AI:
     - Chọn ảnh trong album (tối đa 20 ảnh, preview thumbnail).
     - Nhập gợi ý / ghi chú kỷ niệm (tùy chọn).
     - Lựa chọn Tone phong cách: Lãng mạn, Hài hước, Thơ mộng, Hoài niệm.
     - **Hộp thoại đồng thuận (Mandatory Consent Checkbox)**: Buộc người dùng đánh dấu đồng ý trước khi nút bấm được kích hoạt.
     - Trạng thái loading quay vòng thân thiện trong khi AI đang viết câu chuyện.
3. **Màn hình Câu chuyện kỷ niệm (`mobile/lib/memory_story_screen.dart`)**:
   - Hiển thị tiêu đề, lời kể AI, điểm nhấn đáng nhớ (highlights).
   - Thẻ cảnh báo quyền riêng tư khi ở trạng thái bản nháp.
   - Hộp thoại chỉnh sửa tiêu đề, nội dung, điểm nhấn, phong cách.
   - Nút "Lưu vào Album" (chuyển sang `SAVED`) có thông báo SnackBar xác nhận.

---

## 5. Kết quả Kiểm thử Thực tế & Tình trạng Môi trường

### 5.1. Bảng phân định trạng thái kiểm thử theo môi trường

| Hạng mục kiểm thử | Môi trường | Trạng thái | Chi tiết kết quả |
| :--- | :--- | :---: | :--- |
| **Backend Unit & Integration Tests** | H2 In-Memory, Flyway V1-V8 | **PASS** | **124/124 tests PASS** (0 Failures, 0 Errors, 0 Skipped). Thời gian: 01:15 min. |
| **AI Mock Client Tests** | Offline Mock Provider | **PASS** | 100% tests chạy tự động không cần Internet hay API key bên ngoài. |
| **Gemini Client Parsing & Network Error Tests** | HTTP Mock / Injected Client | **PASS** | 10/10 tests PASS: parse hợp lệ, bóc markdown, timeout, 429, schema sai, không lộ key. |
| **Concurrency & Non-Tx Demarcation Tests** | H2 SpringBootTest | **PASS** | 6/6 tests PASS: atomic rate limit, non-tx AI call, rollback khi lỗi lưu ảnh, lock bảo vệ SAVED. |
| **PostgreSQL 16 Migration & Verification** | Docker / Real PostgreSQL | **BLOCKED** | Môi trường cục bộ Windows thiếu Docker CLI (`docker : The term 'docker' is not recognized`). |
| **Flutter Analyze & UI Widget Tests** | Flutter SDK | **BLOCKED** | Môi trường cục bộ Windows thiếu Flutter SDK (`flutter : The term 'flutter' is not recognized`). |

### 5.2. Chi tiết kết quả Backend Test Suite (`mvnw.cmd test`)
```
[INFO] -------------------------------------------------------
[INFO]  T E S T S
[INFO] -------------------------------------------------------
[INFO] Running com.ourspace.album.AlbumConcurrencyAndIntegrityTest ... [PASS]
[INFO] Running com.ourspace.album.AlbumIntegrationTest ... [PASS]
[INFO] Running com.ourspace.album.service.AlbumServiceTest ... [PASS]
[INFO] Running com.ourspace.album.story.ai.AiPromptBuilderTest ... [PASS]
[INFO] Running com.ourspace.album.story.ai.GeminiAiStoryClientTest ... [PASS] (10 tests)
[INFO] Running com.ourspace.album.story.FlutterContractPayloadTest ... [PASS] (Strict Jackson)
[INFO] Running com.ourspace.album.story.MemoryStoryConcurrencyAndLockingTest ... [PASS] (3 tests)
[INFO] Running com.ourspace.album.story.MemoryStoryIntegrationTest ... [PASS]
[INFO] Running com.ourspace.album.story.MemoryStoryNonTransactionalIntegrationTest ... [PASS] (3 tests)
[INFO] Running com.ourspace.album.story.service.MemoryStoryServiceTest ... [PASS]
[INFO] Running com.ourspace.ApiContractAndSecurityTests ... [PASS]
[INFO] Running com.ourspace.OurSpaceApplicationTests ... [PASS] (Flyway V8 verified)
[INFO] Running com.ourspace.couplespace.CalendarIntegrationTests ... [PASS]
[INFO] Running com.ourspace.identity.AuthIntegrationTest ... [PASS]
[INFO] Running com.ourspace.pairing.PairingConcurrencyTest ... [PASS]
[INFO] Running com.ourspace.pairing.PairingIntegrationTest ... [PASS]
[INFO] Running com.ourspace.photo.PhotoIntegrationTest ... [PASS]
...
[INFO] Results:
[INFO] Tests run: 124, Failures: 0, Errors: 0, Skipped: 0
[INFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
```

---

## 6. Danh sách tập tin thay đổi & tạo mới

### Database & Migrations:
- `backend/src/main/resources/db/migration/V7__create_memory_stories.sql`
- `backend/src/main/resources/db/h2-migration/V7__create_memory_stories.sql`
- `backend/src/main/resources/db/migration/V8__add_memory_stories_version.sql`
- `backend/src/main/resources/db/h2-migration/V8__add_memory_stories_version.sql`

### Backend Source:
- `backend/src/main/resources/application.yml`
- `backend/src/test/resources/application-test.yml`
- `.env.example`
- `backend/src/main/java/com/ourspace/album/story/entity/MemoryStory.java` (thêm `@Version version`)
- `backend/src/main/java/com/ourspace/album/story/entity/MemoryStoryPhoto.java`
- `backend/src/main/java/com/ourspace/album/story/entity/MemoryStoryPhotoId.java`
- `backend/src/main/java/com/ourspace/album/story/entity/MemoryStoryStatus.java`
- `backend/src/main/java/com/ourspace/album/story/repository/MemoryStoryRepository.java` (thêm `findByIdAndCoupleIdWithLock`)
- `backend/src/main/java/com/ourspace/album/story/repository/MemoryStoryPhotoRepository.java`
- `backend/src/main/java/com/ourspace/album/story/dto/CreateMemoryStoryRequest.java` (thêm `@Size(max=50) tone`)
- `backend/src/main/java/com/ourspace/album/story/dto/UpdateMemoryStoryRequest.java`
- `backend/src/main/java/com/ourspace/album/story/dto/AiGeneratedStoryDto.java`
- `backend/src/main/java/com/ourspace/album/story/dto/MemoryStoryResponse.java`
- `backend/src/main/java/com/ourspace/album/story/ai/AiStoryClient.java`
- `backend/src/main/java/com/ourspace/album/story/ai/AiStoryProperties.java` (default `gemini-2.0-flash`)
- `backend/src/main/java/com/ourspace/album/story/ai/MockAiStoryClient.java`
- `backend/src/main/java/com/ourspace/album/story/ai/GeminiAiStoryClient.java` (schema validation, sanitized logging, HttpClient injection)
- `backend/src/main/java/com/ourspace/album/story/ai/AiPromptBuilder.java` (tone mapping & defense-in-depth sanitization)
- `backend/src/main/java/com/ourspace/album/story/ai/AiStoryConfiguration.java`
- `backend/src/main/java/com/ourspace/album/story/service/AiStoryRateLimiter.java` (atomic in-flight reservation & cooldown)
- `backend/src/main/java/com/ourspace/album/story/service/MemoryStoryDraftPersistenceService.java` (atomic persistence & post-AI validation)
- `backend/src/main/java/com/ourspace/album/story/service/MemoryStoryService.java` (rate limiter, non-tx AI call, pessimistic lock)
- `backend/src/main/java/com/ourspace/album/story/controller/MemoryStoryController.java`

### Backend Tests:
- `backend/src/test/java/com/ourspace/OurSpaceApplicationTests.java` (Flyway V8 assert)
- `backend/src/test/java/com/ourspace/album/story/ai/AiPromptBuilderTest.java`
- `backend/src/test/java/com/ourspace/album/story/ai/GeminiAiStoryClientTest.java` (10 unit tests)
- `backend/src/test/java/com/ourspace/album/story/FlutterContractPayloadTest.java` (strict Jackson test)
- `backend/src/test/java/com/ourspace/album/story/MemoryStoryConcurrencyAndLockingTest.java` (3 concurrency tests)
- `backend/src/test/java/com/ourspace/album/story/MemoryStoryNonTransactionalIntegrationTest.java` (3 non-tx demarcation tests)
- `backend/src/test/java/com/ourspace/album/story/service/MemoryStoryServiceTest.java`
- `backend/src/test/java/com/ourspace/album/story/MemoryStoryIntegrationTest.java`

### Mobile Flutter:
- `mobile/lib/data/memory_story_repository.dart`
- `mobile/lib/memory_story_screen.dart`
- `mobile/lib/album_detail_screen.dart`
- `mobile/lib/album_list_screen.dart`
- `mobile/lib/features/pairing/presentation/couple_home_screen.dart`
- `mobile/test/memory_story_repository_test.dart`

### Tài liệu bàn giao:
- `docs/18-m4-sprint3-ai-memory-story.md`
