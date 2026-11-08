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
import com.ourspace.album.story.dto.UpdateMemoryStoryRequest;
import com.ourspace.album.story.entity.MemoryStory;
import com.ourspace.album.story.entity.MemoryStoryStatus;
import com.ourspace.album.story.repository.MemoryStoryPhotoRepository;
import com.ourspace.album.story.repository.MemoryStoryRepository;
import com.ourspace.album.story.service.AiStoryRateLimiter;
import com.ourspace.album.story.service.MemoryStoryDraftPersistenceService;
import com.ourspace.album.story.service.MemoryStoryService;
import com.ourspace.common.exception.ApiException;
import com.ourspace.identity.entity.User;
import com.ourspace.identity.repository.UserRepository;
import com.ourspace.pairing.entity.CoupleEntity;
import com.ourspace.pairing.entity.CoupleMemberEntity;
import com.ourspace.pairing.entity.CoupleStatus;
import com.ourspace.pairing.repository.CoupleMemberRepository;
import com.ourspace.pairing.repository.CoupleRepository;
import com.ourspace.photo.Photo;
import com.ourspace.photo.PhotoRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpStatus;
import org.springframework.test.context.ActiveProfiles;

import java.util.List;
import java.util.UUID;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@SpringBootTest
@ActiveProfiles("test")
class MemoryStoryConcurrencyAndLockingTest {

    @Autowired private UserRepository users;
    @Autowired private CoupleRepository couples;
    @Autowired private CoupleMemberRepository members;
    @Autowired private AlbumRepository albums;
    @Autowired private AlbumPhotoRepository albumPhotos;
    @Autowired private PhotoRepository photos;
    @Autowired private MemoryStoryRepository storyRepository;
    @Autowired private MemoryStoryPhotoRepository storyPhotoRepository;
    @Autowired private MemoryStoryDraftPersistenceService persistenceService;
    @Autowired private AiStoryRateLimiter rateLimiter;
    @Autowired private MemoryStoryService storyService;
    @Autowired private ObjectMapper json;

    private User user;
    private CoupleEntity couple;
    private Album album;
    private Photo photo;

    @BeforeEach
    void setup() {
        user = users.save(new User("concurrent-" + UUID.randomUUID() + "@example.com", "hash", "Concurrent User"));
        couple = couples.save(new CoupleEntity(UUID.randomUUID(), CoupleStatus.ACTIVE));
        members.save(new CoupleMemberEntity(couple, user, "MEMBER"));

        album = albums.save(new Album(UUID.randomUUID(), couple.getId(), "Concurrent Album", null, null, user.getId()));
        photo = photos.save(new Photo(UUID.randomUUID(), couple.getId(), user.getId(), UUID.randomUUID(), "photo.jpg", "image/jpeg", 1024));
        albumPhotos.save(new AlbumPhoto(new AlbumPhotoId(album.getId(), photo.getId())));

        rateLimiter.resetForTest(user.getId());
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
    @DisplayName("Concurrent rate limiting: 5 concurrent threads call createStoryDraft, exactly 1 succeeds, 4 are rejected with 429")
    void concurrentRateLimiting_onlyOneSucceeds() throws Exception {
        // Slow client to simulate AI call delay and ensure overlap
        AiStoryClient slowClient = (albumTitle, photoCount, photoDates, userNotes, requestedTone) -> {
            try {
                Thread.sleep(150);
            } catch (InterruptedException ignored) {}
            return new AiGeneratedStoryDto("Tiêu đề", "Nội dung câu chuyện", List.of("Khoảnh khắc"), "ROMANTIC");
        };

        MemoryStoryService customService = new MemoryStoryService(
                storyRepository, storyPhotoRepository, albums, albumPhotos, couples, photos,
                slowClient, rateLimiter, persistenceService, json
        );

        int threadCount = 5;
        ExecutorService executor = Executors.newFixedThreadPool(threadCount);
        CountDownLatch startGate = new CountDownLatch(1);
        CountDownLatch endGate = new CountDownLatch(threadCount);

        AtomicInteger successCount = new AtomicInteger(0);
        AtomicInteger rateLimitExceededCount = new AtomicInteger(0);

        CreateMemoryStoryRequest req = new CreateMemoryStoryRequest(album.getId(), List.of(photo.getId()), "Ghi chú", "ROMANTIC", true);

        for (int i = 0; i < threadCount; i++) {
            executor.submit(() -> {
                try {
                    startGate.await();
                    customService.createStoryDraft(user.getId(), req);
                    successCount.incrementAndGet();
                } catch (ApiException ae) {
                    if ("AI_SUBMIT_LIMIT_EXCEEDED".equals(ae.code()) && ae.status() == HttpStatus.TOO_MANY_REQUESTS) {
                        rateLimitExceededCount.incrementAndGet();
                    }
                } catch (Exception ignored) {
                } finally {
                    endGate.countDown();
                }
            });
        }

        // Trigger all threads simultaneously
        startGate.countDown();
        boolean completed = endGate.await(10, TimeUnit.SECONDS);
        executor.shutdown();

        assertThat(completed).isTrue();
        assertThat(successCount.get()).as("Chỉ duy nhất 1 luồng được cấp slot gọi AI").isEqualTo(1);
        assertThat(rateLimitExceededCount.get()).as("Các luồng còn lại phải bị từ chối 429").isEqualTo(threadCount - 1);
    }

    @Test
    @DisplayName("Update protection: cannot update a SAVED story or revert it to DRAFT")
    void updateProtection_cannotUpdateSavedStory() {
        CreateMemoryStoryRequest createReq = new CreateMemoryStoryRequest(album.getId(), List.of(photo.getId()), null, "ROMANTIC", true);
        var created = storyService.createStoryDraft(user.getId(), createReq);

        // Transition to SAVED
        var saved = storyService.saveStory(user.getId(), created.id());
        assertThat(saved.status()).isEqualTo("SAVED");

        // Attempting to update the SAVED story must fail with 409 STORY_ALREADY_SAVED
        UpdateMemoryStoryRequest updateReq = new UpdateMemoryStoryRequest("Cố tình sửa", "Cố tình ghi đè", List.of("Hack"), "ROMANTIC");
        assertThatThrownBy(() -> storyService.updateStoryDraft(user.getId(), created.id(), updateReq))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> {
                    ApiException ae = (ApiException) ex;
                    assertThat(ae.status()).isEqualTo(HttpStatus.CONFLICT);
                    assertThat(ae.code()).isEqualTo("STORY_ALREADY_SAVED");
                });

        // Verify database remains untouched and STILL SAVED
        MemoryStory persisted = storyRepository.findById(created.id()).orElseThrow();
        assertThat(persisted.getStatus()).isEqualTo(MemoryStoryStatus.SAVED);
        assertThat(persisted.getTitle()).isEqualTo(created.title());
    }

    @Test
    @DisplayName("Version increment: optimistic version increases upon update and save")
    void versionFieldIncreasesOnModifications() {
        CreateMemoryStoryRequest createReq = new CreateMemoryStoryRequest(album.getId(), List.of(photo.getId()), null, "ROMANTIC", true);
        var created = storyService.createStoryDraft(user.getId(), createReq);

        MemoryStory draftEntity = storyRepository.findById(created.id()).orElseThrow();
        Long v0 = draftEntity.getVersion();
        assertThat(v0).isNotNull();

        // Update draft
        storyService.updateStoryDraft(user.getId(), created.id(), new UpdateMemoryStoryRequest("Sửa lần 1", "Nội dung lần 1", List.of("Ý 1"), "ROMANTIC"));
        MemoryStory updatedEntity = storyRepository.findById(created.id()).orElseThrow();
        assertThat(updatedEntity.getVersion()).isGreaterThan(v0);

        // Save story
        Long v1 = updatedEntity.getVersion();
        storyService.saveStory(user.getId(), created.id());
        MemoryStory savedEntity = storyRepository.findById(created.id()).orElseThrow();
        assertThat(savedEntity.getVersion()).isGreaterThan(v1);
    }
}
