package com.ourspace.photo;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PhotoRepository extends JpaRepository<Photo, UUID> {
    Optional<Photo> findFirstByCoupleIdOrderByCreatedAtDesc(UUID coupleId);
    Optional<Photo> findBySenderIdAndClientRequestId(UUID senderId, UUID clientRequestId);
}
