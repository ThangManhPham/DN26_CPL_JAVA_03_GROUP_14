package com.ourspace.album.story.entity;

import jakarta.persistence.Column;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.time.Instant;

@Entity
@Table(name = "memory_story_photos")
public class MemoryStoryPhoto {

    @EmbeddedId
    private MemoryStoryPhotoId id;

    @Column(name = "added_at", nullable = false)
    private Instant addedAt;

    protected MemoryStoryPhoto() {}

    public MemoryStoryPhoto(MemoryStoryPhotoId id) {
        this.id = id;
        this.addedAt = Instant.now();
    }

    public MemoryStoryPhoto(MemoryStoryPhotoId id, Instant addedAt) {
        this.id = id;
        this.addedAt = addedAt;
    }

    public MemoryStoryPhotoId getId() { return id; }
    public Instant getAddedAt() { return addedAt; }
}

