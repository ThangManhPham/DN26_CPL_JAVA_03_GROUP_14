package com.ourspace.album.service;

import com.ourspace.album.dto.AlbumDetailResponse;
import com.ourspace.album.dto.AlbumResponse;
import com.ourspace.album.dto.CreateAlbumRequest;
import com.ourspace.album.dto.UpdateAlbumRequest;
import com.ourspace.album.entity.Album;
import com.ourspace.album.entity.AlbumPhoto;
import com.ourspace.album.entity.AlbumPhotoId;
import com.ourspace.album.repository.AlbumPhotoRepository;
import com.ourspace.album.repository.AlbumRepository;
import com.ourspace.common.exception.ApiException;
import com.ourspace.pairing.entity.CoupleEntity;
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
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AlbumServiceTest {

    @Mock private AlbumRepository albumRepository;
    @Mock private AlbumPhotoRepository albumPhotoRepository;
    @Mock private CoupleRepository coupleRepository;
    @Mock private PhotoRepository photoRepository;

    @InjectMocks private AlbumService albumService;

    private UUID userId;
    private UUID coupleId;
    private CoupleEntity couple;

    @BeforeEach
    void setUp() {
        userId = UUID.randomUUID();
        coupleId = UUID.randomUUID();
        couple = new CoupleEntity(coupleId, com.ourspace.pairing.entity.CoupleStatus.ACTIVE);
    }

    @Test
    @DisplayName("Tạo album thành công khi có couple hoạt động")
    void createAlbum_success() {
        when(coupleRepository.findActiveCoupleByUserId(userId)).thenReturn(Optional.of(couple));
        when(albumRepository.save(any(Album.class))).thenAnswer(invocation -> invocation.getArgument(0));
        when(albumPhotoRepository.countByIdAlbumId(any(UUID.class))).thenReturn(0L);

        CreateAlbumRequest req = new CreateAlbumRequest("Chuyến đi Đà Lạt", "Kỷ niệm mùa hè", null);
        AlbumResponse res = albumService.createAlbum(userId, req);

        assertThat(res).isNotNull();
        assertThat(res.title()).isEqualTo("Chuyến đi Đà Lạt");
        assertThat(res.description()).isEqualTo("Kỷ niệm mùa hè");
        assertThat(res.coupleId()).isEqualTo(coupleId);
        assertThat(res.photoCount()).isEqualTo(0);

        verify(albumRepository).save(any(Album.class));
    }

    @Test
    @DisplayName("listAlbums sử dụng batch count query để tránh N+1")
    void listAlbums_usesBatchCountQuery() {
        UUID album1Id = UUID.randomUUID();
        UUID album2Id = UUID.randomUUID();
        Album a1 = new Album(album1Id, coupleId, "Album 1", "Mô tả 1", null, userId);
        Album a2 = new Album(album2Id, coupleId, "Album 2", "Mô tả 2", null, userId);

        when(coupleRepository.findActiveCoupleByUserId(userId)).thenReturn(Optional.of(couple));
        when(albumRepository.findByCoupleIdOrderByCreatedAtDesc(coupleId)).thenReturn(List.of(a1, a2));
        when(albumPhotoRepository.countPhotosByAlbumIds(any())).thenReturn(List.of(
                new Object[]{album1Id, 5L},
                new Object[]{album2Id, 12L}
        ));

        List<AlbumResponse> results = albumService.listAlbums(userId);

        assertThat(results).hasSize(2);
        assertThat(results.get(0).photoCount()).isEqualTo(5);
        assertThat(results.get(1).photoCount()).isEqualTo(12);

        verify(albumPhotoRepository, times(1)).countPhotosByAlbumIds(any());
        verify(albumPhotoRepository, never()).countByIdAlbumId(any());
    }

    @Test
    @DisplayName("Tạo album thất bại khi người dùng chưa ghép đôi")
    void createAlbum_noActiveCouple() {
        when(coupleRepository.findActiveCoupleByUserId(userId)).thenReturn(Optional.empty());

        CreateAlbumRequest req = new CreateAlbumRequest("Album mới", null, null);

        assertThatThrownBy(() -> albumService.createAlbum(userId, req))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> {
                    ApiException apiEx = (ApiException) ex;
                    assertThat(apiEx.status()).isEqualTo(HttpStatus.FORBIDDEN);
                    assertThat(apiEx.code()).isEqualTo("NO_ACTIVE_COUPLE");
                });
    }

    @Test
    @DisplayName("Tạo album thất bại khi coverPhotoId thuộc về couple khác")
    void createAlbum_crossCoupleCoverPhoto() {
        UUID crossCoupleId = UUID.randomUUID();
        UUID photoId = UUID.randomUUID();
        Photo photoOfOtherCouple = new Photo(photoId, crossCoupleId, UUID.randomUUID(), UUID.randomUUID(), "key", "image/jpeg", 1024);

        when(coupleRepository.findActiveCoupleByUserId(userId)).thenReturn(Optional.of(couple));
        when(photoRepository.findById(photoId)).thenReturn(Optional.of(photoOfOtherCouple));

        CreateAlbumRequest req = new CreateAlbumRequest("Album vi phạm", null, photoId);

        assertThatThrownBy(() -> albumService.createAlbum(userId, req))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> {
                    ApiException apiEx = (ApiException) ex;
                    assertThat(apiEx.status()).isEqualTo(HttpStatus.FORBIDDEN);
                    assertThat(apiEx.code()).isEqualTo("CROSS_COUPLE_PHOTO");
                });
    }

    @Test
    @DisplayName("Thêm ảnh vào album thành công và tự đặt làm cover nếu chưa có cover")
    void addPhotoToAlbum_success() {
        UUID albumId = UUID.randomUUID();
        UUID photoId = UUID.randomUUID();
        Album album = new Album(albumId, coupleId, "Album 1", "Mô tả", null, userId);
        Photo photo = new Photo(photoId, coupleId, userId, UUID.randomUUID(), "photo_key", "image/png", 2048);

        when(coupleRepository.findActiveCoupleByUserId(userId)).thenReturn(Optional.of(couple));
        when(albumRepository.findByIdAndCoupleId(albumId, coupleId)).thenReturn(Optional.of(album));
        when(photoRepository.findById(photoId)).thenReturn(Optional.of(photo));
        when(albumPhotoRepository.existsById(new AlbumPhotoId(albumId, photoId))).thenReturn(false);
        when(albumRepository.save(any(Album.class))).thenAnswer(invocation -> invocation.getArgument(0));
        when(albumPhotoRepository.countByIdAlbumId(albumId)).thenReturn(1L);

        AlbumResponse res = albumService.addPhotoToAlbum(userId, albumId, photoId);

        assertThat(res.photoCount()).isEqualTo(1);
        assertThat(res.coverPhotoId()).isEqualTo(photoId);
        verify(albumPhotoRepository).save(any(AlbumPhoto.class));
    }

    @Test
    @DisplayName("Thêm ảnh thuộc couple khác bị từ chối 403 CROSS_COUPLE_PHOTO")
    void addPhotoToAlbum_crossCoupleRejected() {
        UUID albumId = UUID.randomUUID();
        UUID photoId = UUID.randomUUID();
        Album album = new Album(albumId, coupleId, "Album 1", "Mô tả", null, userId);
        Photo photo = new Photo(photoId, UUID.randomUUID(), userId, UUID.randomUUID(), "other_key", "image/png", 2048);

        when(coupleRepository.findActiveCoupleByUserId(userId)).thenReturn(Optional.of(couple));
        when(albumRepository.findByIdAndCoupleId(albumId, coupleId)).thenReturn(Optional.of(album));
        when(photoRepository.findById(photoId)).thenReturn(Optional.of(photo));

        assertThatThrownBy(() -> albumService.addPhotoToAlbum(userId, albumId, photoId))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> {
                    ApiException apiEx = (ApiException) ex;
                    assertThat(apiEx.status()).isEqualTo(HttpStatus.FORBIDDEN);
                    assertThat(apiEx.code()).isEqualTo("CROSS_COUPLE_PHOTO");
                });
    }

    @Test
    @DisplayName("Xóa ảnh khỏi album cập nhật lại cover photo hợp lý")
    void removePhotoFromAlbum_updatesCover() {
        UUID albumId = UUID.randomUUID();
        UUID photo1 = UUID.randomUUID();
        UUID photo2 = UUID.randomUUID();
        Album album = new Album(albumId, coupleId, "Album 1", "Mô tả", photo1, userId);

        when(coupleRepository.findActiveCoupleByUserId(userId)).thenReturn(Optional.of(couple));
        when(albumRepository.findByIdAndCoupleId(albumId, coupleId)).thenReturn(Optional.of(album));
        when(albumPhotoRepository.existsById(new AlbumPhotoId(albumId, photo1))).thenReturn(true);
        when(albumPhotoRepository.findByIdAlbumIdOrderByAddedAtDesc(albumId))
                .thenReturn(List.of(new AlbumPhoto(new AlbumPhotoId(albumId, photo2))));
        when(albumRepository.save(any(Album.class))).thenAnswer(invocation -> invocation.getArgument(0));
        when(albumPhotoRepository.countByIdAlbumId(albumId)).thenReturn(1L);

        AlbumResponse res = albumService.removePhotoFromAlbum(userId, albumId, photo1);

        assertThat(res.coverPhotoId()).isEqualTo(photo2);
        verify(albumPhotoRepository).deleteById(new AlbumPhotoId(albumId, photo1));
    }

    @Test
    @DisplayName("Xóa album không xóa ảnh gốc")
    void deleteAlbum_photosNotDeleted() {
        UUID albumId = UUID.randomUUID();
        Album album = new Album(albumId, coupleId, "Album 1", "Mô tả", null, userId);

        when(coupleRepository.findActiveCoupleByUserId(userId)).thenReturn(Optional.of(couple));
        when(albumRepository.findByIdAndCoupleId(albumId, coupleId)).thenReturn(Optional.of(album));

        albumService.deleteAlbum(userId, albumId);

        verify(albumPhotoRepository).deleteByIdAlbumId(albumId);
        verify(albumRepository).delete(album);
        verifyNoInteractions(photoRepository);
    }
}
