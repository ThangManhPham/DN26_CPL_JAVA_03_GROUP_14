package com.ourspace.album;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.ourspace.album.dto.CreateAlbumRequest;
import com.ourspace.album.dto.UpdateAlbumRequest;
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
import java.time.Instant;
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
class AlbumIntegrationTest {

    @Autowired private MockMvc mvc;
    @Autowired private ObjectMapper json;
    @Autowired private UserRepository users;
    @Autowired private CoupleRepository couples;
    @Autowired private CoupleMemberRepository members;
    @Autowired private PhotoRepository photos;
    @Autowired private TokenService tokens;

    private User userA;
    private User userB;
    private User userC;
    private User userD;

    private String tokenA;
    private String tokenB;
    private String tokenC;
    private String tokenD;

    private CoupleEntity couple1;
    private CoupleEntity couple2;

    @BeforeEach
    void setup() {
        userA = users.save(new User("album-a@example.com", "hash", "Alex"));
        userB = users.save(new User("album-b@example.com", "hash", "Sam"));
        userC = users.save(new User("album-c@example.com", "hash", "Charlie"));
        userD = users.save(new User("album-d@example.com", "hash", "Dana"));

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
        tokenD = tokens.issue(userD.getId());
    }

    @Test
    @DisplayName("Truy cập không có token bị từ chối 401 UNAUTHORIZED")
    void unauthenticatedRequestReturns401() throws Exception {
        mvc.perform(get("/api/v1/albums"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    @DisplayName("Người dùng chưa ghép đôi bị từ chối 403 NO_ACTIVE_COUPLE")
    void userWithoutCoupleReturns403() throws Exception {
        User unpaired = users.save(new User("unpaired@example.com", "hash", "Lonely"));
        String unpairedToken = tokens.issue(unpaired.getId());

        CreateAlbumRequest request = new CreateAlbumRequest("Album cá nhân", "Không thể tạo", null);

        mvc.perform(post("/api/v1/albums")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + unpairedToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(request)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("NO_ACTIVE_COUPLE"));
    }

    @Test
    @DisplayName("Validation lỗi khi tiêu đề album để trống -> 422 VALIDATION_ERROR")
    void validationErrorOnEmptyTitle() throws Exception {
        CreateAlbumRequest request = new CreateAlbumRequest("   ", "Mô tả", null);

        mvc.perform(post("/api/v1/albums")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenA)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(request)))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.details.title").exists());
    }

    @Test
    @DisplayName("Toàn bộ quy trình Album giữa hai thành viên trong cặp đôi")
    void fullAlbumLifecycleForCouple() throws Exception {
        // 1. User A tạo album mới
        CreateAlbumRequest createReq = new CreateAlbumRequest("Kỷ niệm 1 năm", "Chuyến đi biển", null);
        String createRes = mvc.perform(post("/api/v1/albums")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenA)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(createReq)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").isNotEmpty())
                .andExpect(jsonPath("$.title").value("Kỷ niệm 1 năm"))
                .andExpect(jsonPath("$.photoCount").value(0))
                .andReturn().getResponse().getContentAsString();

        UUID albumId = UUID.fromString(json.readTree(createRes).get("id").asText());

        // 2. User B xem danh sách album của cặp đôi
        mvc.perform(get("/api/v1/albums")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenB))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(1)))
                .andExpect(jsonPath("$[0].id").value(albumId.toString()))
                .andExpect(jsonPath("$[0].title").value("Kỷ niệm 1 năm"));

        // 3. Chuẩn bị ảnh hợp lệ thuộc về couple1
        UUID photoId = UUID.randomUUID();
        Photo photo = new Photo(photoId, couple1.getId(), userA.getId(), UUID.randomUUID(),
                "storage/key/photo1.jpg", "image/jpeg", 2048);
        photos.save(photo);

        // 4. User B thêm ảnh vào album
        mvc.perform(put("/api/v1/albums/" + albumId + "/photos/" + photoId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenB))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.photoCount").value(1))
                .andExpect(jsonPath("$.coverPhotoId").value(photoId.toString()))
                .andExpect(jsonPath("$.coverPhotoPath").value("/api/v1/photos/" + photoId + "/image"));

        // 5. User A xem chi tiết album
        mvc.perform(get("/api/v1/albums/" + albumId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenA))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(albumId.toString()))
                .andExpect(jsonPath("$.photos", hasSize(1)))
                .andExpect(jsonPath("$.photos[0].id").value(photoId.toString()))
                .andExpect(jsonPath("$.photos[0].imagePath").value("/api/v1/photos/" + photoId + "/image"));

        // 6. User A cập nhật thông tin album
        UpdateAlbumRequest updateReq = new UpdateAlbumRequest("Kỷ niệm 1 năm - Đã đổi tên", "Mô tả mới", photoId);
        mvc.perform(put("/api/v1/albums/" + albumId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenA)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(updateReq)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Kỷ niệm 1 năm - Đã đổi tên"))
                .andExpect(jsonPath("$.description").value("Mô tả mới"));

        // 7. User B xóa ảnh khỏi album
        mvc.perform(delete("/api/v1/albums/" + albumId + "/photos/" + photoId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenB))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.photoCount").value(0))
                .andExpect(jsonPath("$.coverPhotoId").isEmpty());

        // Kiểm tra ảnh gốc vẫn tồn tại trong photos table
        assertThat(photos.findById(photoId)).isPresent();

        // 8. User A xóa album
        mvc.perform(delete("/api/v1/albums/" + albumId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenA))
                .andExpect(status().isNoContent());

        // Kiểm tra album không còn trong danh sách
        mvc.perform(get("/api/v1/albums")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenB))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(0)));
    }

    @Test
    @DisplayName("Cô lập dữ liệu giữa các cặp đôi - Người ngoài không thể xem hoặc sửa album")
    void crossCoupleIsolation() throws Exception {
        // User A tạo album cho Couple 1
        CreateAlbumRequest createReq = new CreateAlbumRequest("Album Couple 1", null, null);
        String createRes = mvc.perform(post("/api/v1/albums")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenA)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(createReq)))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();

        UUID couple1AlbumId = UUID.fromString(json.readTree(createRes).get("id").asText());

        // User C (thuộc Couple 2) cố gắng đọc album của Couple 1 -> 404 ALBUM_NOT_FOUND
        mvc.perform(get("/api/v1/albums/" + couple1AlbumId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenC))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("ALBUM_NOT_FOUND"));

        // Tạo ảnh cho Couple 2
        UUID couple2PhotoId = UUID.randomUUID();
        Photo photoCouple2 = new Photo(couple2PhotoId, couple2.getId(), userC.getId(), UUID.randomUUID(),
                "storage/key/c2.jpg", "image/jpeg", 1024);
        photos.save(photoCouple2);

        // User A (Couple 1) cố tình thêm ảnh của Couple 2 vào album của Couple 1 -> 403 CROSS_COUPLE_PHOTO
        mvc.perform(put("/api/v1/albums/" + couple1AlbumId + "/photos/" + couple2PhotoId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + tokenA))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("CROSS_COUPLE_PHOTO"));
    }
}
