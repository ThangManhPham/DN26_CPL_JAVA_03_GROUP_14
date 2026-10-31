package com.ourspace.album.repository;

import com.ourspace.album.entity.AlbumPhoto;
import com.ourspace.album.entity.AlbumPhotoId;
import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface AlbumPhotoRepository extends JpaRepository<AlbumPhoto, AlbumPhotoId> {
    List<AlbumPhoto> findByIdAlbumIdOrderByAddedAtDesc(UUID albumId);
    long countByIdAlbumId(UUID albumId);
    void deleteByIdAlbumId(UUID albumId);

    @Query("SELECT ap.id.albumId, COUNT(ap.id.photoId) FROM AlbumPhoto ap " +
           "WHERE ap.id.albumId IN :albumIds GROUP BY ap.id.albumId")
    List<Object[]> countPhotosByAlbumIds(@Param("albumIds") Collection<UUID> albumIds);
}
