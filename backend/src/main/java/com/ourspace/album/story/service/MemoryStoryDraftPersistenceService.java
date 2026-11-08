package com.ourspace.album.story.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.ourspace.album.entity.Album;
import com.ourspace.album.entity.AlbumPhotoId;
import com.ourspace.album.repository.AlbumPhotoRepository;
import com.ourspace.album.repository.AlbumRepository;
import com.ourspace.album.story.dto.AiGeneratedStoryDto;
import com.ourspace.album.story.dto.MemoryStoryResponse;
import com.ourspace.album.story.entity.MemoryStory;
import com.ourspace.album.story.entity.MemoryStoryPhoto;
import com.ourspace.album.story.entity.MemoryStoryPhotoId;
import com.ourspace.album.story.entity.MemoryStoryStatus;
import com.ourspace.album.story.repository.MemoryStoryPhotoRepository;
import com.ourspace.album.story.repository.MemoryStoryRepository;
import com.ourspace.common.exception.ApiException;
import com.ourspace.pairing.entity.CoupleEntity;
import com.ourspace.pairing.repository.CoupleRepository;
import com.ourspace.photo.Photo;
import com.ourspace.photo.PhotoRepository;
import java.util.Collections;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

@Service
public class MemoryStoryDraftPersistenceService {

    private static final Logger log = LoggerFactory.getLogger(MemoryStoryDraftPersistenceService.class);

    private final MemoryStoryRepository storyRepository;
    private final MemoryStoryPhotoRepository storyPhotoRepository;
    private final CoupleRepository coupleRepository;
    private final AlbumRepository albumRepository;
    private final AlbumPhotoRepository albumPhotoRepository;
    private final PhotoRepository photoRepository;
    private final ObjectMapper objectMapper;
    private final TransactionTemplate transactionTemplate;

    public MemoryStoryDraftPersistenceService(MemoryStoryRepository storyRepository,
                                             MemoryStoryPhotoRepository storyPhotoRepository,
                                             CoupleRepository coupleRepository,
                                             AlbumRepository albumRepository,
                                             AlbumPhotoRepository albumPhotoRepository,
                                             PhotoRepository photoRepository,
                                             ObjectMapper objectMapper,
                                             PlatformTransactionManager transactionManager) {
        this.storyRepository = storyRepository;
        this.storyPhotoRepository = storyPhotoRepository;
        this.coupleRepository = coupleRepository;
        this.albumRepository = albumRepository;
        this.albumPhotoRepository = albumPhotoRepository;
        this.photoRepository = photoRepository;
        this.objectMapper = objectMapper;
        this.transactionTemplate = new TransactionTemplate(transactionManager);
    }

    @Transactional
    public MemoryStoryResponse persistDraftAtomically(UUID userId, UUID coupleId, UUID albumId, List<UUID> photoIds, AiGeneratedStoryDto generated, String requestedTone) {
        return transactionTemplate.execute(status -> {
            // 1. Re-validate active couple
            CoupleEntity couple = coupleRepository.findActiveCoupleByUserId(userId)
                    .orElseThrow(() -> new ApiException(HttpStatus.FORBIDDEN, "NO_ACTIVE_COUPLE", "Bạn chưa tham gia vào cặp đôi nào đang hoạt động."));

            if (!couple.getId().equals(coupleId)) {
                throw new ApiException(HttpStatus.FORBIDDEN, "COUPLE_CHANGED", "Trạng thái cặp đôi đã thay đổi trong quá trình xử lý.");
            }

            // 2. Re-validate album exists and belongs to couple
            Album album = albumRepository.findByIdAndCoupleId(albumId, coupleId)
                    .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "ALBUM_NOT_FOUND", "Album không tồn tại hoặc đã bị xóa."));

            // 3. Re-validate all photos: exist, belong to couple, and still belong to album
            for (UUID photoId : photoIds) {
                Photo photo = photoRepository.findById(photoId)
                        .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "PHOTO_NOT_FOUND", "Ảnh có mã " + photoId + " không còn tồn tại."));

                if (!photo.getCoupleId().equals(coupleId)) {
                    throw new ApiException(HttpStatus.FORBIDDEN, "CROSS_COUPLE_PHOTO", "Ảnh không thuộc về cặp đôi.");
                }

                if (!albumPhotoRepository.existsById(new AlbumPhotoId(album.getId(), photoId))) {
                    throw new ApiException(HttpStatus.BAD_REQUEST, "PHOTO_NOT_IN_ALBUM", "Ảnh có mã " + photoId + " không còn nằm trong album này.");
                }
            }

            // 4. Serialize highlights
            String highlightsJson;
            try {
                highlightsJson = objectMapper.writeValueAsString(
                        generated.highlights() != null ? generated.highlights() : Collections.emptyList()
                );
            } catch (Exception e) {
                highlightsJson = "[]";
            }

            String effectiveTone = (generated.tone() != null && !generated.tone().isBlank())
                    ? generated.tone().trim().toUpperCase()
                    : (requestedTone != null && !requestedTone.isBlank() ? requestedTone.trim().toUpperCase() : "ROMANTIC");

            UUID storyId = UUID.randomUUID();
            MemoryStory story = new MemoryStory(
                    storyId,
                    coupleId,
                    album.getId(),
                    generated.title() != null ? generated.title().trim() : "Kỷ niệm của chúng mình",
                    generated.story() != null ? generated.story().trim() : "",
                    highlightsJson,
                    effectiveTone,
                    MemoryStoryStatus.DRAFT,
                    userId
            );

            MemoryStory saved = storyRepository.save(story);

            // 5. Save photo links atomically
            for (UUID pid : photoIds) {
                storyPhotoRepository.save(new MemoryStoryPhoto(new MemoryStoryPhotoId(storyId, pid)));
            }

            log.info("Atomically persisted DRAFT memory story id={} for userId={}", storyId, userId);
            return MemoryStoryResponse.from(saved, photoIds);
        });
    }
}
