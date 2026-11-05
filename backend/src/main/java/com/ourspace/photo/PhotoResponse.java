package com.ourspace.photo;

import java.time.Instant;
import java.util.UUID;

public record PhotoResponse(UUID id, UUID coupleId, UUID senderId,
                            String mimeType, long sizeBytes, Instant createdAt, String imagePath) {
    public static PhotoResponse from(Photo photo) {
        return new PhotoResponse(photo.getId(), photo.getCoupleId(), photo.getSenderId(),
                photo.getMimeType(), photo.getSizeBytes(), photo.getCreatedAt(),
                "/api/v1/photos/" + photo.getId() + "/image");
    }
}
