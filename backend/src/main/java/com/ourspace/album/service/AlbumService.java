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
import com.ourspace.photo.PhotoResponse;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional
public class AlbumService {

    private final AlbumRepository albumRepository;
    private final AlbumPhotoRepository albumPhotoRepository;
    private final CoupleRepository coupleRepository;
    private final PhotoRepository photoRepository;

    public AlbumService(AlbumRepository albumRepository,
                        AlbumPhotoRepository albumPhotoRepository,
                        CoupleRepository coupleRepository,
                        PhotoRepository photoRepository) {
        this.albumRepository = albumRepository;
        this.albumPhotoRepository = albumPhotoRepository;
        this.coupleRepository = coupleRepository;
        this.photoRepository = photoRepository;
    }

    public AlbumResponse createAlbum(UUID userId, CreateAlbumRequest request) {
        CoupleEntity couple = getActiveCouple(userId);

        if (request.coverPhotoId() != null) {
            validatePhotoOwnership(request.coverPhotoId(), couple.getId());
        }

        Album album = new Album(
                UUID.randomUUID(),
                couple.getId(),
                request.title().trim(),
                request.description() != null ? request.description().trim() : null,
                request.coverPhotoId(),
                userId
        );
        Album saved = albumRepository.save(album);

        // If cover photo is provided, also add it to album_photos
        if (request.coverPhotoId() != null) {
            albumPhotoRepository.save(new AlbumPhoto(new AlbumPhotoId(saved.getId(), request.coverPhotoId())));
        }

        long count = albumPhotoRepository.countByIdAlbumId(saved.getId());
        return AlbumResponse.from(saved, count);
    }

    @Transactional(readOnly = true)
    public List<AlbumResponse> listAlbums(UUID userId) {
        CoupleEntity couple = getActiveCouple(userId);
        List<Album> albums = albumRepository.findByCoupleIdOrderByCreatedAtDesc(couple.getId());

        return albums.stream()
                .map(album -> {
                    long count = albumPhotoRepository.countByIdAlbumId(album.getId());
                    return AlbumResponse.from(album, count);
                })
                .toList();
    }

    @Transactional(readOnly = true)
    public AlbumDetailResponse getAlbumDetail(UUID userId, UUID albumId) {
        CoupleEntity couple = getActiveCouple(userId);
        Album album = getAlbum(albumId, couple.getId());

        List<AlbumPhoto> albumPhotos = albumPhotoRepository.findByIdAlbumIdOrderByAddedAtDesc(albumId);
        List<UUID> photoIds = albumPhotos.stream()
                .map(ap -> ap.getId().getPhotoId())
                .toList();

        List<PhotoResponse> photos;
        if (photoIds.isEmpty()) {
            photos = Collections.emptyList();
        } else {
            Map<UUID, Photo> photoMap = photoRepository.findAllById(photoIds).stream()
                    .collect(Collectors.toMap(Photo::getId, Function.identity()));

            photos = photoIds.stream()
                    .map(photoMap::get)
                    .filter(java.util.Objects::nonNull)
                    .map(PhotoResponse::from)
                    .toList();
        }

        return AlbumDetailResponse.from(album, photos);
    }

    public AlbumResponse addPhotoToAlbum(UUID userId, UUID albumId, UUID photoId) {
        CoupleEntity couple = getActiveCouple(userId);
        Album album = getAlbum(albumId, couple.getId());
        validatePhotoOwnership(photoId, couple.getId());

        AlbumPhotoId linkId = new AlbumPhotoId(albumId, photoId);
        if (!albumPhotoRepository.existsById(linkId)) {
            albumPhotoRepository.save(new AlbumPhoto(linkId));
        }

        if (album.getCoverPhotoId() == null) {
            album.setCoverPhotoId(photoId);
            album = albumRepository.save(album);
        }

        long count = albumPhotoRepository.countByIdAlbumId(albumId);
        return AlbumResponse.from(album, count);
    }

    public AlbumResponse removePhotoFromAlbum(UUID userId, UUID albumId, UUID photoId) {
        CoupleEntity couple = getActiveCouple(userId);
        Album album = getAlbum(albumId, couple.getId());

        AlbumPhotoId linkId = new AlbumPhotoId(albumId, photoId);
        if (albumPhotoRepository.existsById(linkId)) {
            albumPhotoRepository.deleteById(linkId);

            if (photoId.equals(album.getCoverPhotoId())) {
                List<AlbumPhoto> remaining = albumPhotoRepository.findByIdAlbumIdOrderByAddedAtDesc(albumId);
                UUID nextCover = remaining.isEmpty() ? null : remaining.get(0).getId().getPhotoId();
                album.setCoverPhotoId(nextCover);
                album = albumRepository.save(album);
            }
        }

        long count = albumPhotoRepository.countByIdAlbumId(albumId);
        return AlbumResponse.from(album, count);
    }

    public AlbumResponse updateAlbum(UUID userId, UUID albumId, UpdateAlbumRequest request) {
        CoupleEntity couple = getActiveCouple(userId);
        Album album = getAlbum(albumId, couple.getId());

        if (request.coverPhotoId() != null) {
            validatePhotoOwnership(request.coverPhotoId(), couple.getId());
        }

        album.setTitle(request.title().trim());
        album.setDescription(request.description() != null ? request.description().trim() : null);
        album.setCoverPhotoId(request.coverPhotoId());

        Album saved = albumRepository.save(album);
        long count = albumPhotoRepository.countByIdAlbumId(albumId);
        return AlbumResponse.from(saved, count);
    }

    public void deleteAlbum(UUID userId, UUID albumId) {
        CoupleEntity couple = getActiveCouple(userId);
        Album album = getAlbum(albumId, couple.getId());

        albumPhotoRepository.deleteByIdAlbumId(albumId);
        albumRepository.delete(album);
    }

    @Transactional(readOnly = true)
    public List<PhotoResponse> getAvailablePhotos(UUID userId) {
        CoupleEntity couple = getActiveCouple(userId);
        return photoRepository.findByCoupleIdOrderByCreatedAtDesc(couple.getId()).stream()
                .map(PhotoResponse::from)
                .toList();
    }

    private CoupleEntity getActiveCouple(UUID userId) {
        return coupleRepository.findActiveCoupleByUserId(userId)
                .orElseThrow(() -> new ApiException(
                        HttpStatus.FORBIDDEN,
                        "NO_ACTIVE_COUPLE",
                        "Bạn cần có một mối quan hệ cặp đôi đang hoạt động để truy cập album."
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
