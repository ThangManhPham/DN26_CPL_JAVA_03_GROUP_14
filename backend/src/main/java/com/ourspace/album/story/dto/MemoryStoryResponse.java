package com.ourspace.album.story.dto;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ourspace.album.story.entity.MemoryStory;
import java.time.Instant;
import java.util.Collections;
import java.util.List;
import java.util.UUID;

public record MemoryStoryResponse(
        UUID id,
        UUID coupleId,
        UUID albumId,
        String title,
        String story,
        List<String> highlights,
        String tone,
        String status,
        UUID createdBy,
        List<UUID> selectedPhotoIds,
        Instant createdAt,
        Instant updatedAt
) {
    private static final ObjectMapper MAPPER = new ObjectMapper();

    public static MemoryStoryResponse from(MemoryStory story, List<UUID> photoIds) {
        List<String> hlList = parseHighlights(story.getHighlights());
        return new MemoryStoryResponse(
                story.getId(),
                story.getCoupleId(),
                story.getAlbumId(),
                story.getTitle(),
                story.getStory(),
                hlList,
                story.getTone(),
                story.getStatus().name(),
                story.getCreatedBy(),
                photoIds != null ? photoIds : Collections.emptyList(),
                story.getCreatedAt(),
                story.getUpdatedAt()
        );
    }

    public static List<String> parseHighlights(String json) {
        if (json == null || json.isBlank()) return Collections.emptyList();
        try {
            return MAPPER.readValue(json, new TypeReference<List<String>>() {});
        } catch (Exception e) {
            return List.of(json.split(";"));
        }
    }
}

