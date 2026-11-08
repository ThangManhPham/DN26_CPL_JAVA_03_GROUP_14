package com.ourspace.album.story.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.ourspace.album.entity.Album;
import com.ourspace.album.entity.AlbumPhotoId;
import com.ourspace.album.repository.AlbumPhotoRepository;
import com.ourspace.album.repository.AlbumRepository;
import com.ourspace.album.story.ai.AiPromptBuilder;
import com.ourspace.album.story.ai.AiStoryClient;
import com.ourspace.album.story.ai.AiStoryProperties;
import com.ourspace.album.story.dto.AiGeneratedStoryDto;
import com.ourspace.album.story.dto.CreateMemoryStoryRequest;
import com.ourspace.album.story.dto.MemoryStoryResponse;
import com.ourspace.album.story.dto.UpdateMemoryStoryRequest;
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
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class MemoryStoryService {

    private static final Logger log = LoggerFactory.getLogger(MemoryStoryService.class);
    private static final DateTimeFormatter DATE_FORMATTER = DateTimeFormatter.ofPattern("dd/MM/yyyy").withZone(ZoneOffset.UTC);

    private final MemoryStoryRepository storyRepository;
    private final MemoryStoryPhotoRepository storyPhotoRepository;
    private final AlbumRepository albumRepository;
    private final AlbumPhotoRepository albumPhotoRepository;
    private final CoupleRepository coupleRepository;
    private final PhotoRepository photoRepository;
    private final AiStoryClient aiStoryClient;
    private final AiStoryProperties aiProperties;
    private final ObjectMapper objectMapper;

    public MemoryStoryService(MemoryStoryRepository storyRepository,
                              MemoryStoryPhotoRepository storyPhotoRepository,
                              AlbumRepository albumRepository,
                              AlbumPhotoRepository albumPhotoRepository,
                              CoupleRepository coupleRepository,
                              PhotoRepository photoRepository,
                              AiStoryClient aiStoryClient,
                              AiStoryProperties aiProperties,
                              ObjectMapper objectMapper) {
        this.storyRepository = storyRepository;
        this.storyPhotoRepository = storyPhotoRepository;
        this.albumRepository = albumRepository;
        this.albumPhotoRepository = albumPhotoRepository;
        this.coupleRepository = coupleRepository;
        this.photoRepository = photoRepository;
        this.aiStoryClient = aiStoryClient;
        this.aiProperties = aiProperties;
        this.objectMapper = objectMapper;
    }

    /**
     * Tạo bản nháp Story bằng AI.
     * Cuộc gọi AI diễn ra ngoài Transaction để tránh giữ khóa kết nối DB xuyên suốt mạng ngoài.
     */
    public MemoryStoryResponse createStoryDraft(UUID userId, CreateMemoryStoryRequest request) {
        // 1. Kiểm tra Consent bắt buộc (Privacy-First)
        if (request.consent() == null || !request.consent()) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "AI_CONSENT_REQUIRED",
                    "Bạn cần xác nhận đồng ý để gửi dữ liệu kỷ niệm cho hệ thống AI xử lý."
            );
        }

        // 2. Kiểm tra thông tin Album, Couple & Ảnh (Pre-AI validation)
        CoupleEntity couple = getActiveCouple(userId);
        Album album = getAlbum(request.albumId(), couple.getId());

        List<UUID> photoIds = request.selectedPhotoIds();
        if (photoIds == null || photoIds.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "NO_PHOTOS_SELECTED", "Cần chọn ít nhất một bức ảnh từ album.");
        }
        if (photoIds.size() > 20) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "TOO_MANY_PHOTOS", "Chỉ được chọn tối đa 20 ảnh cho một câu chuyện kỷ niệm.");
        }

        // Kiểm tra từng ảnh: phải thuộc couple và phải nằm trong album được chỉ định
        List<String> photoDates = new ArrayList<>();
        for (UUID photoId : photoIds) {
            validatePhotoOwnership(photoId, couple.getId());
            if (!albumPhotoRepository.existsById(new AlbumPhotoId(album.getId(), photoId))) {
                throw new ApiException(
                        HttpStatus.BAD_REQUEST,
                        "PHOTO_NOT_IN_ALBUM",
                        "Ảnh có mã " + photoId + " không thuộc về album này."
                );
            }
            Photo photo = photoRepository.findById(photoId).orElse(null);
            if (photo != null && photo.getCreatedAt() != null) {
                photoDates.add(DATE_FORMATTER.format(photo.getCreatedAt()));
            }
        }

        // 3. Rate-limit guard chống spam submit
        Instant windowStart = Instant.now().minus(aiProperties.getRateLimitWindowMinutes(), ChronoUnit.MINUTES);
        long recentDrafts = storyRepository.countRecentDraftsByUser(couple.getId(), userId, windowStart);
        if (recentDrafts >= aiProperties.getMaxDraftsPerWindow()) {
            throw new ApiException(
                    HttpStatus.TOO_MANY_REQUESTS,
                    "AI_SUBMIT_LIMIT_EXCEEDED",
                    "Bạn đã tạo " + recentDrafts + " bản nháp trong " + aiProperties.getRateLimitWindowMinutes() +
                    " phút qua. Vui lòng hoàn thành các bản nháp trước khi tạo thêm."
            );
        }

        // 4. Lời gọi AI (Không giữ khóa / Transaction DB)
        log.info("Generating AI Memory Story for albumId={}, photoCount={}", album.getId(), photoIds.size());
        AiGeneratedStoryDto generated = aiStoryClient.generateStory(album.getTitle(), photoIds.size(), photoDates, request.notes());

        // 5. Lưu kết quả dưới dạng DRAFT trong Transaction
        return persistDraft(userId, couple.getId(), album.getId(), photoIds, generated);
    }

    @Transactional
    public MemoryStoryResponse persistDraft(UUID userId, UUID coupleId, UUID albumId, List<UUID> photoIds, AiGeneratedStoryDto generated) {
        // Kiểm tra lại tính toàn vẹn (đề phòng unpair hoặc album bị xóa trong khi AI đang xử lý)
        CoupleEntity couple = getActiveCouple(userId);
        if (!couple.getId().equals(coupleId)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "COUPLE_CHANGED", "Trạng thái cặp đôi đã thay đổi trong quá trình xử lý.");
        }
        Album album = getAlbum(albumId, coupleId);

        String highlightsJson;
        try {
            highlightsJson = objectMapper.writeValueAsString(
                    generated.highlights() != null ? generated.highlights() : Collections.emptyList()
            );
        } catch (Exception e) {
            highlightsJson = "[]";
        }

        UUID storyId = UUID.randomUUID();
        MemoryStory story = new MemoryStory(
                storyId,
                coupleId,
                album.getId(),
                generated.title() != null ? generated.title().trim() : "Kỷ niệm của chúng mình",
                generated.story() != null ? generated.story().trim() : "",
                highlightsJson,
                generated.tone() != null ? generated.tone().trim() : "warm",
                MemoryStoryStatus.DRAFT,
                userId
        );

        MemoryStory saved = storyRepository.save(story);

        for (UUID pid : photoIds) {
            storyPhotoRepository.save(new MemoryStoryPhoto(new MemoryStoryPhotoId(storyId, pid)));
        }

        log.info("Successfully persisted DRAFT memory story id={} for userId={}", storyId, userId);
        return MemoryStoryResponse.from(saved, photoIds);
    }

    @Transactional(readOnly = true)
    public MemoryStoryResponse getStory(UUID userId, UUID storyId) {
        CoupleEntity couple = getActiveCouple(userId);
        MemoryStory story = storyRepository.findByIdAndCoupleId(storyId, couple.getId())
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "STORY_NOT_FOUND", "Không tìm thấy câu chuyện kỷ niệm."));

        // Quyền truy cập: DRAFT chỉ người tạo mới xem được; SAVED cả couple xem được
        if (story.getStatus() == MemoryStoryStatus.DRAFT && !story.getCreatedBy().equals(userId)) {
            throw new ApiException(
                    HttpStatus.FORBIDDEN,
                    "DRAFT_ACCESS_DENIED",
                    "Bản nháp câu chuyện chỉ người tạo mới có quyền truy cập."
            );
        }

        List<UUID> photoIds = storyPhotoRepository.findByIdStoryId(storyId).stream()
                .map(p -> p.getId().getPhotoId())
                .toList();

        return MemoryStoryResponse.from(story, photoIds);
    }

    @Transactional
    public MemoryStoryResponse updateStoryDraft(UUID userId, UUID storyId, UpdateMemoryStoryRequest request) {
        CoupleEntity couple = getActiveCouple(userId);
        MemoryStory story = storyRepository.findByIdAndCoupleId(storyId, couple.getId())
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "STORY_NOT_FOUND", "Không tìm thấy câu chuyện kỷ niệm."));

        if (story.getStatus() == MemoryStoryStatus.SAVED) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "CANNOT_EDIT_SAVED_STORY",
                    "Câu chuyện đã được lưu vào không gian chung, không thể chỉnh sửa trong phiên bản hiện tại."
            );
        }

        if (!story.getCreatedBy().equals(userId)) {
            throw new ApiException(
                    HttpStatus.FORBIDDEN,
                    "DRAFT_ACCESS_DENIED",
                    "Chỉ người tạo bản nháp mới có quyền chỉnh sửa nội dung."
            );
        }

        story.setTitle(request.title().trim());
        story.setStory(request.story().trim());
        if (request.tone() != null && !request.tone().isBlank()) {
            story.setTone(request.tone().trim());
        }

        if (request.highlights() != null) {
            try {
                story.setHighlights(objectMapper.writeValueAsString(request.highlights()));
            } catch (Exception e) {
                story.setHighlights("[]");
            }
        }

        MemoryStory saved = storyRepository.save(story);
        List<UUID> photoIds = storyPhotoRepository.findByIdStoryId(storyId).stream()
                .map(p -> p.getId().getPhotoId())
                .toList();

        return MemoryStoryResponse.from(saved, photoIds);
    }

    @Transactional
    public MemoryStoryResponse saveStory(UUID userId, UUID storyId) {
        CoupleEntity couple = getActiveCouple(userId);
        MemoryStory story = storyRepository.findByIdAndCoupleId(storyId, couple.getId())
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "STORY_NOT_FOUND", "Không tìm thấy câu chuyện kỷ niệm."));

        // Tính Idempotent: Nếu đã SAVED, trả về thành công trực tiếp mà không lỗi
        if (story.getStatus() == MemoryStoryStatus.SAVED) {
            List<UUID> photoIds = storyPhotoRepository.findByIdStoryId(storyId).stream()
                    .map(p -> p.getId().getPhotoId())
                    .toList();
            return MemoryStoryResponse.from(story, photoIds);
        }

        if (!story.getCreatedBy().equals(userId)) {
            throw new ApiException(
                    HttpStatus.FORBIDDEN,
                    "DRAFT_ACCESS_DENIED",
                    "Chỉ người tạo bản nháp mới có quyền lưu câu chuyện."
            );
        }

        story.setStatus(MemoryStoryStatus.SAVED);
        MemoryStory saved = storyRepository.save(story);

        List<UUID> photoIds = storyPhotoRepository.findByIdStoryId(storyId).stream()
                .map(p -> p.getId().getPhotoId())
                .toList();

        log.info("Memory story id={} successfully transitioned to SAVED by userId={}", storyId, userId);
        return MemoryStoryResponse.from(saved, photoIds);
    }

    @Transactional(readOnly = true)
    public List<MemoryStoryResponse> listStoriesForAlbum(UUID userId, UUID albumId) {
        CoupleEntity couple = getActiveCouple(userId);
        // Kiểm tra album thuộc couple
        getAlbum(albumId, couple.getId());

        List<MemoryStory> stories = storyRepository.findVisibleStoriesForUser(albumId, userId);
        return stories.stream()
                .map(s -> {
                    List<UUID> photoIds = storyPhotoRepository.findByIdStoryId(s.getId()).stream()
                            .map(p -> p.getId().getPhotoId())
                            .toList();
                    return MemoryStoryResponse.from(s, photoIds);
                })
                .toList();
    }

    private CoupleEntity getActiveCouple(UUID userId) {
        return coupleRepository.findActiveCoupleByUserId(userId)
                .orElseThrow(() -> new ApiException(
                        HttpStatus.FORBIDDEN,
                        "NO_ACTIVE_COUPLE",
                        "Bạn chưa tham gia vào cặp đôi nào đang hoạt động."
                ));
    }

    private Album getAlbum(UUID albumId, UUID coupleId) {
        return albumRepository.findByIdAndCoupleId(albumId, coupleId)
                .orElseThrow(() -> new ApiException(
                        HttpStatus.NOT_FOUND,
                        "ALBUM_NOT_FOUND",
                        "Album không tồn tại hoặc bạn không có quyền truy cập."
                ));
    }

    private void validatePhotoOwnership(UUID photoId, UUID coupleId) {
        Photo photo = photoRepository.findById(photoId)
                .orElseThrow(() -> new ApiException(
                        HttpStatus.NOT_FOUND,
                        "PHOTO_NOT_FOUND",
                        "Không tìm thấy ảnh được chỉ định."
                ));

        if (!photo.getCoupleId().equals(coupleId)) {
            throw new ApiException(
                    HttpStatus.FORBIDDEN,
                    "CROSS_COUPLE_PHOTO",
                    "Không được phép sử dụng ảnh từ cặp đôi khác."
            );
        }
    }
}

