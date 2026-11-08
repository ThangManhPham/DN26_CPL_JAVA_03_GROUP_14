package com.ourspace.album.story;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.ourspace.album.entity.Album;
import com.ourspace.album.entity.AlbumPhoto;
import com.ourspace.album.entity.AlbumPhotoId;
import com.ourspace.album.repository.AlbumPhotoRepository;
import com.ourspace.album.repository.AlbumRepository;
import com.ourspace.album.story.dto.CreateMemoryStoryRequest;
import com.ourspace.album.story.dto.UpdateMemoryStoryRequest;
import com.ourspace.album.story.entity.MemoryStoryStatus;
import com.ourspace.identity.entity.User;
import com.ourspace.identity.repository.UserRepository;
import com.ourspace.pairing.entity.CoupleEntity;
import com.ourspace.pairing.entity.CoupleMemberEntity;
import com.ourspace.pairing.entity.CoupleStatus;
import com.ourspace.pairing.repository.CoupleMemberRepository;
import com.ourspace.pairing.repository.CoupleRepository;
import com.ourspace.photo.Photo;
import com.ourspace.photo.PhotoRepository;
import com.ourspace.security.TokenService;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class MemoryStoryIntegrationTest {

    @Autowired private MockMvc mvc;
    @Autowired private ObjectMapper json;
    @Autowired private UserRepository users;
    @Autowired private CoupleRepository couples;
    @Autowired private CoupleMemberRepository members;
    @Autowired private AlbumRepository albums;
    @Autowired private AlbumPhotoRepository albumPhotos;
    @Autowired private PhotoRepository photos;
    @Autowired private TokenService tokens;

    private User userA;
    private User userB;
    private User userC;
    private User userD;

    private String tokenA;
    private String tokenB;
    private String tokenC;

    private CoupleEntity couple1;
    private CoupleEntity couple2;

    private Album album1;
    private Photo photo1;
    private Photo photo2;

    @BeforeEach
    void setup() {
        userA = users.save(new User("story-a@example.com", "hash", "Alice"));
        userB = users.save(new User("story-b@example.com", "hash", "Bob"));
        userC = users.save(new User("story-c@example.com", "hash", "Charlie"));
        userD = users.save(new User("story-d@example.com", "hash", "Diana"));

        // Couple 1: A + B
        couple1 = couples.save(new CoupleEntity(UUID.randomUUID(), CoupleStatus.ACTIVE));
        members.save(new CoupleMemberEntity(couple1, userA, "MEMBER"));
        members.save(new CoupleMemberEntity(couple1, userB, "MEMBER"));

        // Couple 2: C + D
        couple2 = couples.save(new CoupleEntity(UUID.randomUUID(), CoupleStatus.ACTIVE));
        members.save(new CoupleMemberEntity(couple2, userC, "MEMBER"));
        members.save(new CoupleMemberEntity(couple2, userD, "MEMBER"));

        tokenA = tokens.issue(userA.getId());
        tokenB = tokens.issue(userB.getId());
        tokenC = tokens.issue(userC.getId());

        // Setup Album for Couple 1
        album1 = albums.save(new Album(UUID.randomUUID(), couple1.getId(), "Chuyến đi Đà Lạt", "Kỷ niệm mùa hoa dã quỳ", null, userA.getId()));

        photo1 = photos.save(new Photo(UUID.randomUUID(), couple1.getId(), userA.getId(), UUID.randomUUID(),
                "storage/key/dalat1.jpg", "image/jpeg", 2048));
        photo2 = photos.save(new Photo(UUID.randomUUID(), couple1.getId(), userB.getId(), UUID.randomUUID(),
                "storage/key/dalat2.jpg", "image/jpeg", 4096));

        albumPhotos.save(new AlbumPhoto(new AlbumPhotoId(album1.getId(), photo1.getId())));
        albumPhotos.save(new AlbumPhoto(new AlbumPhotoId(album1.getId(), photo2.getId())));
    }

    @Test
    @DisplayName("Truy cập không có token bị từ chối 401 UNAUTHORIZED")
    void unauthenticatedReturns401() throws Exception {
        mvc.perform(get("/api/v1/albums/" + album1.getId() + "/stories"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    @DisplayName("Người dùng chưa ghép đôi bị từ chối 403 NO_ACTIVE_COUPLE")
    void unpairedUserReturns403() throws Exception {
        User unpaired = users.save(new User("story-unpaired@example.com", "hash", "Solo"));
        String unpairedToken = tokens.issue(unpaired.getId());

        CreateMemoryStoryRequest req = new CreateMemoryStoryRequest(
                album1.getId(),
                List.of(photo1.getId()),
                "Ghi chú",
                true
        );

        mvc.perform(post("/api/v1/ai/memory-stories")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + unpairedToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(req)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("NO_ACTIVE_COUPLE"));
    }

    @Test
    @DisplayName("Thiếu sự đồng thuận (consent=false) bị từ chối 400 AI_CONSENT_REQUIRED")
    void missingConsentReturns400() throws Exception {
        CreateMemoryStoryRequest req = new CreateMemoryStoryRequest(
                album1.getId(),
                List.of(photo1.getId()),
                "Ghi chú",
                false
        );

        mvc.perform(post("/api/v1/ai/memory-stories")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenA)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(req)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("AI_CONSENT_REQUIRED"));
    }

    @Test
    @DisplayName("Ảnh không thuộc album bị từ chối 400 PHOTO_NOT_IN_ALBUM")
    void photoNotInAlbumReturns400() throws Exception {
        Photo photoNotInAlbum = photos.save(new Photo(UUID.randomUUID(), couple1.getId(), userA.getId(), UUID.randomUUID(),
                "storage/key/other.jpg", "image/jpeg", 1024));

        CreateMemoryStoryRequest req = new CreateMemoryStoryRequest(
                album1.getId(),
                List.of(photoNotInAlbum.getId()),
                "Ghi chú",
                true
        );

        mvc.perform(post("/api/v1/ai/memory-stories")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenA)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(req)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("PHOTO_NOT_IN_ALBUM"));
    }

    @Test
    @DisplayName("Toàn bộ vòng đời AI Memory Story: Tạo Draft -> Xem -> Chỉnh sửa -> Lưu -> Đối phương xem")
    void fullMemoryStoryLifecycle() throws Exception {
        // 1. User A tạo bản nháp câu chuyện từ AI
        CreateMemoryStoryRequest createReq = new CreateMemoryStoryRequest(
                album1.getId(),
                List.of(photo1.getId(), photo2.getId()),
                "Chuyến đi đầu tiên của chúng mình đến xứ sở ngàn hoa",
                true
        );

        String createRes = mvc.perform(post("/api/v1/ai/memory-stories")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenA)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(createReq)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").isNotEmpty())
                .andExpect(jsonPath("$.albumId").value(album1.getId().toString()))
                .andExpect(jsonPath("$.status").value("DRAFT"))
                .andExpect(jsonPath("$.title").isNotEmpty())
                .andExpect(jsonPath("$.story").isNotEmpty())
                .andExpect(jsonPath("$.highlights", not(empty())))
                .andExpect(jsonPath("$.selectedPhotoIds", hasSize(2)))
                .andReturn().getResponse().getContentAsString();

        UUID storyId = UUID.fromString(json.readTree(createRes).get("id").asText());

        // 2. Tác giả (User A) có thể đọc bản nháp
        mvc.perform(get("/api/v1/ai/memory-stories/" + storyId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenA))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(storyId.toString()))
                .andExpect(jsonPath("$.status").value("DRAFT"));

        // 3. Đối phương (User B) KHÔNG ĐƯỢC đọc bản nháp của tác giả -> 403 DRAFT_ACCESS_DENIED
        mvc.perform(get("/api/v1/ai/memory-stories/" + storyId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenB))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("DRAFT_ACCESS_DENIED"));

        // 4. Đối phương (User B) cố tình sửa bản nháp -> 403 DRAFT_ACCESS_DENIED
        UpdateMemoryStoryRequest partnerEdit = new UpdateMemoryStoryRequest("Tiêu đề của B", "Nội dung của B", List.of("Ý 1"), "ROMANTIC");
        mvc.perform(put("/api/v1/ai/memory-stories/" + storyId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenB)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(partnerEdit)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("DRAFT_ACCESS_DENIED"));

        // 5. Tác giả (User A) chỉnh sửa bản nháp
        UpdateMemoryStoryRequest authorEdit = new UpdateMemoryStoryRequest(
                "Đà Lạt - Kỷ Niệm Tình Yêu Của Chúng Mình",
                "Chúng mình đã cùng nhau đi qua những cung đường đèo tuyệt đẹp...",
                List.of("Đón bình minh tại đồi chè", "Thưởng thức lẩu gà lá é ấm nồng"),
                "ROMANTIC"
        );
        mvc.perform(put("/api/v1/ai/memory-stories/" + storyId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenA)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(authorEdit)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Đà Lạt - Kỷ Niệm Tình Yêu Của Chúng Mình"))
                .andExpect(jsonPath("$.story").value("Chúng mình đã cùng nhau đi qua những cung đường đèo tuyệt đẹp..."))
                .andExpect(jsonPath("$.highlights", hasSize(2)))
                .andExpect(jsonPath("$.status").value("DRAFT"));

        // 6. Tác giả (User A) chính thức lưu câu chuyện vào Album
        mvc.perform(post("/api/v1/ai/memory-stories/" + storyId + "/save")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenA))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("SAVED"));

        // 7. Bây giờ đối phương (User B) CÓ THỂ xem câu chuyện đã lưu
        mvc.perform(get("/api/v1/ai/memory-stories/" + storyId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenB))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(storyId.toString()))
                .andExpect(jsonPath("$.status").value("SAVED"))
                .andExpect(jsonPath("$.title").value("Đà Lạt - Kỷ Niệm Tình Yêu Của Chúng Mình"));

        // 8. Không thể sửa câu chuyện đã lưu -> 400 CANNOT_EDIT_SAVED_STORY
        mvc.perform(put("/api/v1/ai/memory-stories/" + storyId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenA)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(authorEdit)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("CANNOT_EDIT_SAVED_STORY"));

        // 9. Lưu lại một câu chuyện đã lưu là idempotent -> 200 SAVED
        mvc.perform(post("/api/v1/ai/memory-stories/" + storyId + "/save")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenA))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("SAVED"));

        // 10. Cả hai đều thấy câu chuyện đã lưu trong danh sách stories của Album
        mvc.perform(get("/api/v1/albums/" + album1.getId() + "/stories")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenA))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(1)))
                .andExpect(jsonPath("$[0].id").value(storyId.toString()));

        mvc.perform(get("/api/v1/albums/" + album1.getId() + "/stories")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenB))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(1)))
                .andExpect(jsonPath("$[0].id").value(storyId.toString()));
    }

    @Test
    @DisplayName("Quyền riêng tư bản nháp trong danh sách Album: Đối tác không thấy bản nháp của tác giả")
    void draftPrivacyInAlbumStoryList() throws Exception {
        // Tác giả A tạo bản nháp
        CreateMemoryStoryRequest createReq = new CreateMemoryStoryRequest(
                album1.getId(),
                List.of(photo1.getId()),
                "Nháp bí mật",
                true
        );

        mvc.perform(post("/api/v1/ai/memory-stories")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenA)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(createReq)))
                .andExpect(status().isCreated());

        // A xem danh sách -> Thấy 1 bản nháp
        mvc.perform(get("/api/v1/albums/" + album1.getId() + "/stories")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenA))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(1)))
                .andExpect(jsonPath("$[0].status").value("DRAFT"));

        // B xem danh sách -> KHÔNG thấy bản nháp của A
        mvc.perform(get("/api/v1/albums/" + album1.getId() + "/stories")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenB))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(0)));
    }

    @Test
    @DisplayName("Cô lập dữ liệu giữa các cặp đôi - Người ngoài không thể xem hoặc tạo story")
    void crossCoupleIsolation() throws Exception {
        // A tạo 1 bản nháp trong Album 1 của Couple 1
        CreateMemoryStoryRequest createReq = new CreateMemoryStoryRequest(
                album1.getId(),
                List.of(photo1.getId()),
                "Kỷ niệm couple 1",
                true
        );
        String res = mvc.perform(post("/api/v1/ai/memory-stories")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenA)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(createReq)))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();

        UUID storyId = UUID.fromString(json.readTree(res).get("id").asText());

        // User C (Couple 2) cố gắng đọc story của Couple 1 -> 404 STORY_NOT_FOUND
        mvc.perform(get("/api/v1/ai/memory-stories/" + storyId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenC))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("STORY_NOT_FOUND"));

        // User C cố gắng lấy danh sách stories trong album của Couple 1 -> 404 ALBUM_NOT_FOUND
        mvc.perform(get("/api/v1/albums/" + album1.getId() + "/stories")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenC))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("ALBUM_NOT_FOUND"));

        // User C cố gắng tạo story trong album của Couple 1 -> 404 ALBUM_NOT_FOUND
        mvc.perform(post("/api/v1/ai/memory-stories")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenC)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(createReq)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("ALBUM_NOT_FOUND"));
    }
}
