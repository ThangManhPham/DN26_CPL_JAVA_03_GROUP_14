package com.ourspace.album.story.dto;

import java.util.List;

public record AiGeneratedStoryDto(
        String title,
        String story,
        List<String> highlights,
        String tone
) {}

