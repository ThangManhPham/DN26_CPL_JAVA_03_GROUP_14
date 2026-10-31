package com.ourspace.album.repository;

import com.ourspace.album.entity.Album;
import jakarta.persistence.LockModeType;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface AlbumRepository extends JpaRepository<Album, UUID> {
    List<Album> findByCoupleIdOrderByCreatedAtDesc(UUID coupleId);
    Optional<Album> findByIdAndCoupleId(UUID id, UUID coupleId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT a FROM Album a WHERE a.id = :id AND a.coupleId = :coupleId")
    Optional<Album> findByIdAndCoupleIdForUpdate(@Param("id") UUID id, @Param("coupleId") UUID coupleId);
}
