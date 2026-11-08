package com.ourspace.album.story.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import java.io.Serializable;
import java.util.Objects;
import java.util.UUID;

@Embeddable
public class MemoryStoryPhotoId implements Serializable {

    @Column(name = "story_id", nullable = false)
    private UUID storyId;

    @Column(name = "photo_id", nullable = false)
    private UUID photoId;

    protected MemoryStoryPhotoId() {}

    public MemoryStoryPhotoId(UUID storyId, UUID photoId) {
        this.storyId = storyId;
        this.photoId = photoId;
    }

    public UUID getStoryId() { return storyId; }
    public UUID getPhotoId() { return photoId; }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof MemoryStoryPhotoId that)) return false;
        return Objects.equals(storyId, that.storyId) && Objects.equals(photoId, that.photoId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(storyId, photoId);
    }
}

