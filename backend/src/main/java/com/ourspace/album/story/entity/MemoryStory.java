package com.ourspace.album.story.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "memory_stories")
public class MemoryStory {

    @Id
    private UUID id;

    @Column(name = "couple_id", nullable = false)
    private UUID coupleId;

    @Column(name = "album_id", nullable = false)
    private UUID albumId;

    @Column(name = "title", nullable = false, length = 200)
    private String title;

    @Column(name = "story", nullable = false, columnDefinition = "TEXT")
    private String story;

    @Column(name = "highlights", nullable = false, columnDefinition = "TEXT")
    private String highlights;

    @Column(name = "tone", nullable = false, length = 50)
    private String tone;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private MemoryStoryStatus status;

    @Column(name = "created_by", nullable = false)
    private UUID createdBy;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Version
    @Column(name = "version", nullable = false)
    private Long version = 0L;

    protected MemoryStory() {}

    public MemoryStory(UUID id, UUID coupleId, UUID albumId, String title, String story,
                       String highlights, String tone, MemoryStoryStatus status, UUID createdBy) {
        this.id = id;
        this.coupleId = coupleId;
        this.albumId = albumId;
        this.title = title;
        this.story = story;
        this.highlights = highlights;
        this.tone = tone;
        this.status = status;
        this.createdBy = createdBy;
        this.createdAt = Instant.now();
        this.updatedAt = Instant.now();
    }

    public UUID getId() { return id; }
    public UUID getCoupleId() { return coupleId; }
    public UUID getAlbumId() { return albumId; }
    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; this.updatedAt = Instant.now(); }
    public String getStory() { return story; }
    public void setStory(String story) { this.story = story; this.updatedAt = Instant.now(); }
    public String getHighlights() { return highlights; }
    public void setHighlights(String highlights) { this.highlights = highlights; this.updatedAt = Instant.now(); }
    public String getTone() { return tone; }
    public void setTone(String tone) { this.tone = tone; this.updatedAt = Instant.now(); }
    public MemoryStoryStatus getStatus() { return status; }
    public void setStatus(MemoryStoryStatus status) { this.status = status; this.updatedAt = Instant.now(); }
    public UUID getCreatedBy() { return createdBy; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
    public Long getVersion() { return version; }
}

