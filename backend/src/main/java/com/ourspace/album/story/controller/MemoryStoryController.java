package com.ourspace.album.story.controller;

import com.ourspace.album.story.dto.CreateMemoryStoryRequest;
import com.ourspace.album.story.dto.MemoryStoryResponse;
import com.ourspace.album.story.dto.UpdateMemoryStoryRequest;
import com.ourspace.album.story.service.MemoryStoryService;
import com.ourspace.security.SecurityUtils;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class MemoryStoryController {

    private final MemoryStoryService storyService;

    public MemoryStoryController(MemoryStoryService storyService) {
        this.storyService = storyService;
    }

    @PostMapping("/ai/memory-stories")
    public ResponseEntity<MemoryStoryResponse> createStoryDraft(
            Authentication auth,
            @Valid @RequestBody CreateMemoryStoryRequest request) {
        UUID userId = SecurityUtils.resolveUserId(auth);
        MemoryStoryResponse response = storyService.createStoryDraft(userId, request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @GetMapping("/ai/memory-stories/{id}")
    public MemoryStoryResponse getStory(
            Authentication auth,
            @PathVariable UUID id) {
        UUID userId = SecurityUtils.resolveUserId(auth);
        return storyService.getStory(userId, id);
    }

    @PutMapping("/ai/memory-stories/{id}")
    public MemoryStoryResponse updateStoryDraft(
            Authentication auth,
            @PathVariable UUID id,
            @Valid @RequestBody UpdateMemoryStoryRequest request) {
        UUID userId = SecurityUtils.resolveUserId(auth);
        return storyService.updateStoryDraft(userId, id, request);
    }

    @PostMapping("/ai/memory-stories/{id}/save")
    public MemoryStoryResponse saveStory(
            Authentication auth,
            @PathVariable UUID id) {
        UUID userId = SecurityUtils.resolveUserId(auth);
        return storyService.saveStory(userId, id);
    }

    @GetMapping("/albums/{albumId}/stories")
    public List<MemoryStoryResponse> listStoriesForAlbum(
            Authentication auth,
            @PathVariable UUID albumId) {
        UUID userId = SecurityUtils.resolveUserId(auth);
        return storyService.listStoriesForAlbum(userId, albumId);
    }
}

