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
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
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
        verify(albumRepository).save(any(Album.class));
    }

    @Test
    @DisplayName("Tạo album có kèm coverPhoto tự động thêm cover photo vào album_photos")
    void createAlbum_withCoverPhoto_addsToAlbumPhotos() {
        UUID photoId = UUID.randomUUID();
        Photo photo = new Photo(photoId, coupleId, userId, UUID.randomUUID(), "photo_key", "image/png", 2048);

        when(coupleRepository.findActiveCoupleByUserId(userId)).thenReturn(Optional.of(couple));
        when(photoRepository.findById(photoId)).thenReturn(Optional.of(photo));
        when(albumRepository.save(any(Album.class))).thenAnswer(invocation -> invocation.getArgument(0));
        when(albumPhotoRepository.countByIdAlbumId(any(UUID.class))).thenReturn(1L);

        CreateAlbumRequest req = new CreateAlbumRequest("Album có ảnh bìa", "Mô tả", photoId);
        AlbumResponse res = albumService.createAlbum(userId, req);

        assertThat(res.coverPhotoId()).isEqualTo(photoId);
        verify(albumPhotoRepository).save(any(AlbumPhoto.class));
    }

    @Test
    @DisplayName("Tạo album thất bại khi user chưa có couple")
    void createAlbum_noActiveCouple() {
        when(coupleRepository.findActiveCoupleByUserId(userId)).thenReturn(Optional.empty());

        CreateAlbumRequest req = new CreateAlbumRequest("Album 1", null, null);

        assertThatThrownBy(() -> albumService.createAlbum(userId, req))
                .isInstanceOf(ApiException.class)
                .satisfies(ex -> {
                    ApiException apiEx = (ApiException) ex;
                    assertThat(apiEx.status()).isEqualTo(HttpStatus.FORBIDDEN);
                    assertThat(apiEx.code()).isEqualTo("NO_ACTIVE_COUPLE");
                });
    }

    @Test
    @DisplayName("Liệt kê danh sách album sử dụng batch count query (không N+1)")
    void listAlbums_usesBatchCountQuery() {
        when(coupleRepository.findActiveCoupleByUserId(userId)).thenReturn(Optional.of(couple));

        UUID a1 = UUID.randomUUID();
        UUID a2 = UUID.randomUUID();
        Album album1 = new Album(a1, coupleId, "Album 1", "Mô tả 1", null, userId);
        Album album2 = new Album(a2, coupleId, "Album 2", "Mô tả 2", null, userId);

        when(albumRepository.findByCoupleIdOrderByCreatedAtDesc(coupleId)).thenReturn(List.of(album1, album2));
        when(albumPhotoRepository.countPhotosByAlbumIds(List.of(a1, a2)))
                .thenReturn(List.of(new Object[]{a1, 5L}, new Object[]{a2, 3L}));

        List<AlbumResponse> list = albumService.listAlbums(userId);

        assertThat(list).hasSize(2);
        assertThat(list.get(0).photoCount()).isEqualTo(5L);
        assertThat(list.get(1).photoCount()).isEqualTo(3L);
        verify(albumPhotoRepository, times(1)).countPhotosByAlbumIds(any());
        verify(albumPhotoRepository, never()).countByIdAlbumId(any());
    }

    @Test
    @DisplayName("Tạo album với cover photo của couple khác bị từ chối 403 CROSS_COUPLE_PHOTO")
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
        when(albumRepository.findByIdAndCoupleIdForUpdate(albumId, coupleId)).thenReturn(Optional.of(album));
        when(photoRepository.findById(photoId)).thenReturn(Optional.of(photo));
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
        when(albumRepository.findByIdAndCoupleIdForUpdate(albumId, coupleId)).thenReturn(Optional.of(album));
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
        when(albumRepository.findByIdAndCoupleIdForUpdate(albumId, coupleId)).thenReturn(Optional.of(album));
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
    @DisplayName("Cập nhật album với ảnh bìa mới tự động đảm bảo ảnh thuộc album")
    void updateAlbum_ensuresCoverPhotoBelongsToAlbum() {
        UUID albumId = UUID.randomUUID();
        UUID photoId = UUID.randomUUID();
        Album album = new Album(albumId, coupleId, "Album cũ", "Mô tả cũ", null, userId);
        Photo photo = new Photo(photoId, coupleId, userId, UUID.randomUUID(), "photo_key", "image/png", 2048);

        when(coupleRepository.findActiveCoupleByUserId(userId)).thenReturn(Optional.of(couple));
        when(albumRepository.findByIdAndCoupleIdForUpdate(albumId, coupleId)).thenReturn(Optional.of(album));
        when(photoRepository.findById(photoId)).thenReturn(Optional.of(photo));
        when(albumRepository.save(any(Album.class))).thenAnswer(invocation -> invocation.getArgument(0));
        when(albumPhotoRepository.countByIdAlbumId(albumId)).thenReturn(1L);

        UpdateAlbumRequest req = new UpdateAlbumRequest("Album mới", "Mô tả mới", photoId);
        AlbumResponse res = albumService.updateAlbum(userId, albumId, req);

        assertThat(res.title()).isEqualTo("Album mới");
        assertThat(res.coverPhotoId()).isEqualTo(photoId);
        verify(albumPhotoRepository).save(any(AlbumPhoto.class));
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
