package com.ourspace.album.dto;

import com.ourspace.album.entity.Album;
import java.time.Instant;
import java.util.UUID;

public record AlbumResponse(
        UUID id,
        UUID coupleId,
        String title,
        String description,
        UUID coverPhotoId,
        String coverPhotoPath,
        long photoCount,
        UUID createdBy,
        Instant createdAt,
        Instant updatedAt
) {
    public static AlbumResponse from(Album album, long photoCount) {
        String coverPath = album.getCoverPhotoId() != null
                ? "/api/v1/photos/" + album.getCoverPhotoId() + "/image"
                : null;
        return new AlbumResponse(
                album.getId(),
                album.getCoupleId(),
                album.getTitle(),
                album.getDescription(),
                album.getCoverPhotoId(),
                coverPath,
                photoCount,
                album.getCreatedBy(),
                album.getCreatedAt(),
                album.getUpdatedAt()
        );
    }
}
