package com.ourspace.album.repository;

import com.ourspace.album.entity.AlbumPhoto;
import com.ourspace.album.entity.AlbumPhotoId;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface AlbumPhotoRepository extends JpaRepository<AlbumPhoto, AlbumPhotoId> {
    List<AlbumPhoto> findByIdAlbumIdOrderByAddedAtDesc(UUID albumId);
    long countByIdAlbumId(UUID albumId);
    void deleteByIdAlbumId(UUID albumId);
}
