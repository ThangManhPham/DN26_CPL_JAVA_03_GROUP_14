package com.ourspace.album.repository;

import com.ourspace.album.entity.Album;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface AlbumRepository extends JpaRepository<Album, UUID> {
    List<Album> findByCoupleIdOrderByCreatedAtDesc(UUID coupleId);
    Optional<Album> findByIdAndCoupleId(UUID id, UUID coupleId);
}
