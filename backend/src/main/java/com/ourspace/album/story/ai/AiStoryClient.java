package com.ourspace.album.story.ai;

import com.ourspace.album.story.dto.AiGeneratedStoryDto;
import java.util.List;

public interface AiStoryClient {
    AiGeneratedStoryDto generateStory(String albumTitle, int photoCount, List<String> photoDates, String userNotes, String requestedTone);
}

