package com.ourspace.album.story.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.ourspace.album.entity.Album;
import com.ourspace.album.entity.AlbumPhotoId;
import com.ourspace.album.repository.AlbumPhotoRepository;
import com.ourspace.album.repository.AlbumRepository;
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
import com.ourspace.pairing.entity.CoupleStatus;
import com.ourspace.pairing.repository.CoupleRepository;
import com.ourspace.photo.Photo;
import com.ourspace.photo.PhotoRepository;
import java.time.Instant;
import java.util.Collections;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.Spy;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class MemoryStoryServiceTest {

    @Mock private MemoryStoryRepository storyRepository;
    @Mock private MemoryStoryPhotoRepository storyPhotoRepository;
    @Mock private AlbumRepository albumRepository;
    @Mock private AlbumPhotoRepository albumPhotoRepository;
    @Mock private CoupleRepository coupleRepository;
    @Mock private PhotoRepository photoRepository;
    @Mock private AiStoryClient aiStoryClient;
    @Spy private AiStoryProperties aiProperties = new AiStoryProperties();
    @Spy private ObjectMapper objectMapper = new ObjectMapper();

    @InjectMocks private MemoryStoryService storyService;

    private UUID userId;
    private UUID partnerId;
    private UUID coupleId;
    private CoupleEntity couple;
    private UUID albumId;
    private Album album;
    private UUID photo1Id;
    private UUID photo2Id;
    private Photo photo1;
    private Photo photo2;

    @BeforeEach
    void setUp() {
        userId = UUID.randomUUID();
        partnerId = UUID.randomUUID();
        coupleId = UUID.randomUUID();
        couple = new CoupleEntity(coupleId, CoupleStatus.ACTIVE);

        albumId = UUID.randomUUID();
        album = new Album(albumId, coupleId, "Chuyến đi Đà Lạt", "Kỷ niệm mùa hè", null, userId);

        photo1Id = UUID.randomUUID();
        photo2Id = UUID.randomUUID();
        photo1 = new Photo(photo1Id, coupleId, userId, UUID.randomUUID(), "k1", "image/png", 1024);
        photo2 = new Photo(photo2Id, coupleId, partnerId, UUID.randomUUID(), "k2", "image/png", 2048);
    }

    @Test
    @DisplayName("Tạo bản nháp Story thành công khi có consent và ảnh hợp lệ")
    void createStoryDraft_success() {
        when(coupleRepository.findActiveCoupleByUserId(userId)).thenReturn(Optional.of(couple));
        when(albumRepository.findByIdAndCoupleId(albumId, coupleId)).thenReturn(Optional.of(album));
        when(photoRepository.findById(photo1Id)).thenReturn(Optional.of(photo1));
        when(albumPhotoRepository.existsById(new AlbumPhotoId(albumId, photo1Id))).thenReturn(true);
        when(storyRepository.countRecentDraftsByUser(eq(coupleId), eq(userId), any())).thenReturn(0L);

        AiGeneratedStoryDto aiResult = new AiGeneratedStoryDto(
                "Đà Lạt trong sương",
                "Chúng mình đã cùng nhau ngắm bình minh tuyệt đẹp...",
                List.of("Bình minh", "Hồ Xuân Hương"),
                "warm"
        );
        when(aiStoryClient.generateStory(eq("Chuyến đi Đà Lạt"), eq(1), any(), eq("Thật vui"))).thenReturn(aiResult);
        when(storyRepository.save(any(MemoryStory.class))).thenAnswer(inv -> inv.getArgument(0));

        CreateMemoryStoryRequest req = new CreateMemoryStoryRequest(albumId, List.of(photo1Id), "Thật vui", true);
        MemoryStoryResponse res = storyService.createStoryDraft(userId, req);

        assertThat(res).isNotNull();
        assertThat(res.title()).isEqualTo("Đà Lạt trong sương");
        assertThat(res.status()).isEqualTo("DRAFT");
        assertThat(res.createdBy()).isEqualTo(userId);
        assertThat(res.highlights()).containsExactly("Bình minh", "Hồ Xuân Hương");

        verify(storyPhotoRepository).save(any(MemoryStoryPhoto.class));
    }

    @Test
    @DisplayName("Từ chối tạo Story khi thiếu Consent (consent=null hoặc consent=false) -> 400 AI_CONSENT_REQUIRED")
    void createStoryDraft_noConsent_rejected() {
        CreateMemoryStoryRequest reqNull = new CreateMemoryStoryRequest(albumId, List.of(photo1Id), "Ghi chú", null);
        assertThatThrownBy(() -> storyService.createStoryDraft(userId, reqNull))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> {
                    ApiException apiEx = (ApiException) ex;
                    assertThat(apiEx.status()).isEqualTo(HttpStatus.BAD_REQUEST);
                    assertThat(apiEx.code()).isEqualTo("AI_CONSENT_REQUIRED");
                });

        CreateMemoryStoryRequest reqFalse = new CreateMemoryStoryRequest(albumId, List.of(photo1Id), "Ghi chú", false);
        assertThatThrownBy(() -> storyService.createStoryDraft(userId, reqFalse))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> {
                    ApiException apiEx = (ApiException) ex;
                    assertThat(apiEx.status()).isEqualTo(HttpStatus.BAD_REQUEST);
                    assertThat(apiEx.code()).isEqualTo("AI_CONSENT_REQUIRED");
                });

        verifyNoInteractions(aiStoryClient);
    }

    @Test
    @DisplayName("Từ chối khi ảnh không nằm trong album được chỉ định -> 400 PHOTO_NOT_IN_ALBUM")
    void createStoryDraft_photoNotInAlbum_rejected() {
        when(coupleRepository.findActiveCoupleByUserId(userId)).thenReturn(Optional.of(couple));
        when(albumRepository.findByIdAndCoupleId(albumId, coupleId)).thenReturn(Optional.of(album));
        when(photoRepository.findById(photo1Id)).thenReturn(Optional.of(photo1));
        when(albumPhotoRepository.existsById(new AlbumPhotoId(albumId, photo1Id))).thenReturn(false);

        CreateMemoryStoryRequest req = new CreateMemoryStoryRequest(albumId, List.of(photo1Id), "Ghi chú", true);
        assertThatThrownBy(() -> storyService.createStoryDraft(userId, req))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> {
                    ApiException apiEx = (ApiException) ex;
                    assertThat(apiEx.status()).isEqualTo(HttpStatus.BAD_REQUEST);
                    assertThat(apiEx.code()).isEqualTo("PHOTO_NOT_IN_ALBUM");
                });

        verifyNoInteractions(aiStoryClient);
    }

    @Test
    @DisplayName("Từ chối khi ảnh thuộc couple khác -> 403 CROSS_COUPLE_PHOTO")
    void createStoryDraft_crossCouplePhoto_rejected() {
        UUID otherCoupleId = UUID.randomUUID();
        Photo otherPhoto = new Photo(photo1Id, otherCoupleId, userId, UUID.randomUUID(), "k3", "image/png", 1024);

        when(coupleRepository.findActiveCoupleByUserId(userId)).thenReturn(Optional.of(couple));
        when(albumRepository.findByIdAndCoupleId(albumId, coupleId)).thenReturn(Optional.of(album));
        when(photoRepository.findById(photo1Id)).thenReturn(Optional.of(otherPhoto));

        CreateMemoryStoryRequest req = new CreateMemoryStoryRequest(albumId, List.of(photo1Id), "Ghi chú", true);
        assertThatThrownBy(() -> storyService.createStoryDraft(userId, req))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> {
                    ApiException apiEx = (ApiException) ex;
                    assertThat(apiEx.status()).isEqualTo(HttpStatus.FORBIDDEN);
                    assertThat(apiEx.code()).isEqualTo("CROSS_COUPLE_PHOTO");
                });

        verifyNoInteractions(aiStoryClient);
    }

    @Test
    @DisplayName("Bảo mật DRAFT: Người tạo xem được DRAFT của mình, partner bị từ chối 403 DRAFT_ACCESS_DENIED")
    void getStory_draftPrivacyEnforced() {
        UUID storyId = UUID.randomUUID();
        MemoryStory draft = new MemoryStory(
                storyId, coupleId, albumId, "Bản nháp riêng", "Nội dung...", "[]", "warm",
                MemoryStoryStatus.DRAFT, userId
        );

        when(coupleRepository.findActiveCoupleByUserId(userId)).thenReturn(Optional.of(couple));
        when(coupleRepository.findActiveCoupleByUserId(partnerId)).thenReturn(Optional.of(couple));
        when(storyRepository.findByIdAndCoupleId(storyId, coupleId)).thenReturn(Optional.of(draft));
        when(storyPhotoRepository.findByIdStoryId(storyId)).thenReturn(Collections.emptyList());

        // 1. Người tạo xem -> Thành công
        MemoryStoryResponse creatorRes = storyService.getStory(userId, storyId);
        assertThat(creatorRes).isNotNull();
        assertThat(creatorRes.title()).isEqualTo("Bản nháp riêng");

        // 2. Partner xem -> 403 DRAFT_ACCESS_DENIED
        assertThatThrownBy(() -> storyService.getStory(partnerId, storyId))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> {
                    ApiException apiEx = (ApiException) ex;
                    assertThat(apiEx.status()).isEqualTo(HttpStatus.FORBIDDEN);
                    assertThat(apiEx.code()).isEqualTo("DRAFT_ACCESS_DENIED");
                });
    }

    @Test
    @DisplayName("Cả hai thành viên couple đều xem được Story khi đã ở trạng thái SAVED")
    void getStory_bothMembersCanViewSaved() {
        UUID storyId = UUID.randomUUID();
        MemoryStory savedStory = new MemoryStory(
                storyId, coupleId, albumId, "Câu chuyện chung", "Kỷ niệm...", "[]", "warm",
                MemoryStoryStatus.SAVED, userId
        );

        when(coupleRepository.findActiveCoupleByUserId(partnerId)).thenReturn(Optional.of(couple));
        when(storyRepository.findByIdAndCoupleId(storyId, coupleId)).thenReturn(Optional.of(savedStory));
        when(storyPhotoRepository.findByIdStoryId(storyId)).thenReturn(Collections.emptyList());

        MemoryStoryResponse partnerRes = storyService.getStory(partnerId, storyId);
        assertThat(partnerRes).isNotNull();
        assertThat(partnerRes.status()).isEqualTo("SAVED");
        assertThat(partnerRes.title()).isEqualTo("Câu chuyện chung");
    }

    @Test
    @DisplayName("Chỉnh sửa DRAFT thành công bởi người tạo, từ chối khi sửa SAVED story")
    void updateStoryDraft_lifecycleChecks() {
        UUID storyId = UUID.randomUUID();
        MemoryStory draft = new MemoryStory(
                storyId, coupleId, albumId, "Tiêu đề cũ", "Nội dung cũ", "[]", "warm",
                MemoryStoryStatus.DRAFT, userId
        );

        when(coupleRepository.findActiveCoupleByUserId(userId)).thenReturn(Optional.of(couple));
        when(storyRepository.findByIdAndCoupleId(storyId, coupleId)).thenReturn(Optional.of(draft));
        when(storyRepository.save(any(MemoryStory.class))).thenAnswer(inv -> inv.getArgument(0));
        when(storyPhotoRepository.findByIdStoryId(storyId)).thenReturn(Collections.emptyList());

        UpdateMemoryStoryRequest updateReq = new UpdateMemoryStoryRequest(
                "Tiêu đề mới đã sửa",
                "Nội dung mới chi tiết hơn...",
                List.of("Điểm nhấn 1"),
                "romantic"
        );

        // 1. Chỉnh sửa bản nháp -> Thành công
        MemoryStoryResponse updated = storyService.updateStoryDraft(userId, storyId, updateReq);
        assertThat(updated.title()).isEqualTo("Tiêu đề mới đã sửa");
        assertThat(updated.story()).isEqualTo("Nội dung mới chi tiết hơn...");
        assertThat(updated.tone()).isEqualTo("romantic");

        // 2. Chuyển story sang SAVED rồi thử sửa -> 400 CANNOT_EDIT_SAVED_STORY
        draft.setStatus(MemoryStoryStatus.SAVED);
        assertThatThrownBy(() -> storyService.updateStoryDraft(userId, storyId, updateReq))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> {
                    ApiException apiEx = (ApiException) ex;
                    assertThat(apiEx.status()).isEqualTo(HttpStatus.BAD_REQUEST);
                    assertThat(apiEx.code()).isEqualTo("CANNOT_EDIT_SAVED_STORY");
                });
    }

    @Test
    @DisplayName("Lưu Story chính thức (Save) thành công và đảm bảo tính Idempotent khi gọi lại")
    void saveStory_idempotentSuccess() {
        UUID storyId = UUID.randomUUID();
        MemoryStory story = new MemoryStory(
                storyId, coupleId, albumId, "Kỷ niệm", "Nội dung...", "[]", "warm",
                MemoryStoryStatus.DRAFT, userId
        );

        when(coupleRepository.findActiveCoupleByUserId(userId)).thenReturn(Optional.of(couple));
        when(storyRepository.findByIdAndCoupleId(storyId, coupleId)).thenReturn(Optional.of(story));
        when(storyRepository.save(any(MemoryStory.class))).thenAnswer(inv -> inv.getArgument(0));
        when(storyPhotoRepository.findByIdStoryId(storyId)).thenReturn(Collections.emptyList());

        // Lần 1: Chuyển từ DRAFT -> SAVED
        MemoryStoryResponse res1 = storyService.saveStory(userId, storyId);
        assertThat(res1.status()).isEqualTo("SAVED");
        verify(storyRepository, times(1)).save(any(MemoryStory.class));

        // Lần 2: Gọi lại khi đã SAVED -> Idempotent thành công, không gọi save lần nữa
        MemoryStoryResponse res2 = storyService.saveStory(userId, storyId);
        assertThat(res2.status()).isEqualTo("SAVED");
        verify(storyRepository, times(1)).save(any(MemoryStory.class));
    }
}

