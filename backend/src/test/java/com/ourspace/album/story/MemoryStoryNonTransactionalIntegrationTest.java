package com.ourspace.album.story;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.ourspace.album.entity.Album;
import com.ourspace.album.entity.AlbumPhoto;
import com.ourspace.album.entity.AlbumPhotoId;
import com.ourspace.album.repository.AlbumPhotoRepository;
import com.ourspace.album.repository.AlbumRepository;
import com.ourspace.album.story.ai.AiStoryClient;
import com.ourspace.album.story.dto.AiGeneratedStoryDto;
import com.ourspace.album.story.dto.CreateMemoryStoryRequest;
import com.ourspace.album.story.repository.MemoryStoryPhotoRepository;
import com.ourspace.album.story.repository.MemoryStoryRepository;
import com.ourspace.album.story.service.AiStoryRateLimiter;
import com.ourspace.album.story.service.MemoryStoryDraftPersistenceService;
import com.ourspace.album.story.service.MemoryStoryService;
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
import java.util.concurrent.atomic.AtomicBoolean;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Integration Test KHÔNG có @Transactional bao ngoài test method.
 * Chứng minh:
 * 1. Không có transaction active trong lúc gọi AI provider.
 * 2. Lỗi khi lưu liên kết ảnh rollback cả MemoryStory.
 * 3. Luồng thật commit và đọc lại dữ liệu thành công xuyên suốt các transaction riêng biệt.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class MemoryStoryNonTransactionalIntegrationTest {

    @Autowired private MockMvc mvc;
    @Autowired private ObjectMapper json;
    @Autowired private UserRepository users;
    @Autowired private CoupleRepository couples;
    @Autowired private CoupleMemberRepository members;
    @Autowired private AlbumRepository albums;
    @Autowired private AlbumPhotoRepository albumPhotos;
    @Autowired private PhotoRepository photos;
    @Autowired private TokenService tokens;
    @Autowired private MemoryStoryRepository storyRepository;
    @Autowired private MemoryStoryPhotoRepository storyPhotoRepository;
    @Autowired private AiStoryRateLimiter rateLimiter;
    @Autowired private PlatformTransactionManager transactionManager;
    @Autowired private MemoryStoryService storyService;

    private User user;
    private CoupleEntity couple;
    private Album album;
    private Photo photo;
    private String token;

    @BeforeEach
    void setup() {
        user = users.save(new User("nontx-user-" + UUID.randomUUID() + "@example.com", "hash", "NonTx Tester"));
        couple = couples.save(new CoupleEntity(UUID.randomUUID(), CoupleStatus.ACTIVE));
        members.save(new CoupleMemberEntity(couple, user, "MEMBER"));
        token = tokens.issue(user.getId());

        rateLimiter.resetForTest(user.getId());

        album = albums.save(new Album(UUID.randomUUID(), couple.getId(), "Album Non-Tx Test", null, null, user.getId()));
        photo = photos.save(new Photo(UUID.randomUUID(), couple.getId(), user.getId(), UUID.randomUUID(), "nontx.jpg", "image/jpeg", 2048));
        albumPhotos.save(new AlbumPhoto(new AlbumPhotoId(album.getId(), photo.getId())));
    }

    @AfterEach
    void cleanup() {
        rateLimiter.resetForTest(user.getId());
        storyPhotoRepository.deleteAll();
        storyRepository.deleteAll();
        albumPhotos.deleteAll();
        albums.deleteAll();
        photos.deleteAll();
        members.deleteAll();
        couples.deleteAll();
        users.deleteAll();
    }

    @Test
    @DisplayName("Chứng minh: Không có transaction đang hoạt động trong lúc gọi AI provider")
    void noActiveTransactionDuringAiCall() {
        AtomicBoolean wasInTx = new AtomicBoolean(true);

        AiStoryClient monitoringClient = (albumTitle, photoCount, photoDates, userNotes, requestedTone) -> {
            // Kiểm tra trạng thái transaction hiện tại của thread này
            wasInTx.set(TransactionSynchronizationManager.isActualTransactionActive());
            return new AiGeneratedStoryDto("Tiêu đề", "Nội dung", List.of("Ý 1"), "ROMANTIC");
        };

        MemoryStoryDraftPersistenceService persistenceService = new MemoryStoryDraftPersistenceService(
                storyRepository, storyPhotoRepository, couples, albums, albumPhotos, photos, json, transactionManager
        );

        MemoryStoryService customService = new MemoryStoryService(
                storyRepository, storyPhotoRepository, albums, albumPhotos, couples, photos,
                monitoringClient, rateLimiter, persistenceService, json
        );

        CreateMemoryStoryRequest req = new CreateMemoryStoryRequest(album.getId(), List.of(photo.getId()), "Ghi chú", "ROMANTIC", true);
        customService.createStoryDraft(user.getId(), req);

        // Khẳng định: Trong lúc gọi AI, TransactionSynchronizationManager.isActualTransactionActive() phải là FALSE!
        assertThat(wasInTx.get())
                .as("Lời gọi AI phải được thực thi hoàn toàn ngoài Spring Transaction")
                .isFalse();
    }

    @Test
    @DisplayName("Chứng minh: Lỗi khi lưu liên kết ảnh rollback toàn bộ Story đã lưu")
    void failureSavingPhotoLinks_rollsBackStory() {
        MemoryStoryPhotoRepository failingPhotoRepo = mock(MemoryStoryPhotoRepository.class);
        doThrow(new DataIntegrityViolationException("Simulated constraint violation when linking photo"))
                .when(failingPhotoRepo).save(any());

        MemoryStoryDraftPersistenceService failingPersistenceService = new MemoryStoryDraftPersistenceService(
                storyRepository, failingPhotoRepo, couples, albums, albumPhotos, photos, json, transactionManager
        );

        AiGeneratedStoryDto aiResult = new AiGeneratedStoryDto("Tiêu đề", "Nội dung", List.of("Ý 1"), "ROMANTIC");

        long storiesBefore = storyRepository.count();

        assertThatThrownBy(() -> failingPersistenceService.persistDraftAtomically(
                user.getId(), couple.getId(), album.getId(), List.of(photo.getId()), aiResult, "ROMANTIC"
        )).isInstanceOf(DataIntegrityViolationException.class);

        // Khẳng định: Toàn bộ Story đã được rollback và không có bản ghi nào bị rò rỉ trong DB
        long storiesAfter = storyRepository.count();
        assertThat(storiesAfter).isEqualTo(storiesBefore);
    }

    @Test
    @DisplayName("Chứng minh: Luồng request HTTP thật commit và đọc lại dữ liệu thành công mà không có @Transactional test")
    void realRequestCommitsAndCanBeReadBack() throws Exception {
        CreateMemoryStoryRequest req = new CreateMemoryStoryRequest(album.getId(), List.of(photo.getId()), "Thực tế", "ROMANTIC", true);

        // 1. Tạo Story qua HTTP POST
        String responseBody = mvc.perform(post("/api/v1/ai/memory-stories")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(req)))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();

        UUID storyId = UUID.fromString(json.readTree(responseBody).get("id").asText());

        // 2. Query trực tiếp từ DB chứng minh dữ liệu đã thực sự được COMMIT vào DB
        assertThat(storyRepository.findById(storyId)).isPresent();
        assertThat(storyPhotoRepository.findByIdStoryId(storyId)).hasSize(1);

        // 3. Đọc lại qua HTTP GET độc lập
        mvc.perform(get("/api/v1/ai/memory-stories/" + storyId)
                        .header(HttpHeaders.AUTHORIZATION, "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(storyId.toString()))
                .andExpect(jsonPath("$.status").value("DRAFT"));
    }
}
