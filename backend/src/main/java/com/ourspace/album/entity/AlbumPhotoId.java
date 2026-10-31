package com.ourspace.album.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import java.io.Serializable;
import java.util.Objects;
import java.util.UUID;

@Embeddable
public class AlbumPhotoId implements Serializable {
    @Column(name = "album_id", nullable = false)
    private UUID albumId;

    @Column(name = "photo_id", nullable = false)
    private UUID photoId;

    public AlbumPhotoId() {}

    public AlbumPhotoId(UUID albumId, UUID photoId) {
        this.albumId = albumId;
        this.photoId = photoId;
    }

    public UUID getAlbumId() { return albumId; }
    public UUID getPhotoId() { return photoId; }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        AlbumPhotoId that = (AlbumPhotoId) o;
        return Objects.equals(albumId, that.albumId) && Objects.equals(photoId, that.photoId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(albumId, photoId);
    }
}
