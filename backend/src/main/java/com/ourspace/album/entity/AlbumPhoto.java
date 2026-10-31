package com.ourspace.album.entity;

import jakarta.persistence.Column;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.time.Instant;

@Entity
@Table(name = "album_photos")
public class AlbumPhoto {
    @EmbeddedId
    private AlbumPhotoId id;

    @Column(name = "added_at", nullable = false)
    private Instant addedAt;

    protected AlbumPhoto() {}

    public AlbumPhoto(AlbumPhotoId id) {
        this.id = id;
        this.addedAt = Instant.now();
    }

    public AlbumPhoto(AlbumPhotoId id, Instant addedAt) {
        this.id = id;
        this.addedAt = addedAt;
    }

    public AlbumPhotoId getId() { return id; }
    public Instant getAddedAt() { return addedAt; }
}
