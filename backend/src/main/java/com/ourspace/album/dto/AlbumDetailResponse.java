package com.ourspace.album.dto;

import com.ourspace.album.entity.Album;
import com.ourspace.photo.PhotoResponse;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record AlbumDetailResponse(
        UUID id,
        UUID coupleId,
        String title,
        String description,
        UUID coverPhotoId,
        String coverPhotoPath,
        UUID createdBy,
        Instant createdAt,
        Instant updatedAt,
        List<PhotoResponse> photos
) {
    public static AlbumDetailResponse from(Album album, List<PhotoResponse> photos) {
        String coverPath = album.getCoverPhotoId() != null
                ? "/api/v1/photos/" + album.getCoverPhotoId() + "/image"
                : null;
        return new AlbumDetailResponse(
                album.getId(),
                album.getCoupleId(),
                album.getTitle(),
                album.getDescription(),
                album.getCoverPhotoId(),
                coverPath,
                album.getCreatedBy(),
                album.getCreatedAt(),
                album.getUpdatedAt(),
                photos
        );
    }
}
