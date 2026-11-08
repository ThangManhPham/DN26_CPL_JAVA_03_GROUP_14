package com.ourspace.album.story.repository;

import com.ourspace.album.story.entity.MemoryStory;
import com.ourspace.album.story.entity.MemoryStoryStatus;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface MemoryStoryRepository extends JpaRepository<MemoryStory, UUID> {

    List<MemoryStory> findByAlbumIdOrderByCreatedAtDesc(UUID albumId);

    Optional<MemoryStory> findByIdAndCoupleId(UUID id, UUID coupleId);

    @Query("SELECT s FROM MemoryStory s WHERE s.albumId = :albumId AND " +
           "(s.status = 'SAVED' OR (s.status = 'DRAFT' AND s.createdBy = :userId)) " +
           "ORDER BY s.createdAt DESC")
    List<MemoryStory> findVisibleStoriesForUser(@Param("albumId") UUID albumId, @Param("userId") UUID userId);

    @Query("SELECT COUNT(s) FROM MemoryStory s WHERE s.coupleId = :coupleId AND s.createdBy = :userId " +
           "AND s.status = 'DRAFT' AND s.createdAt > :since")
    long countRecentDraftsByUser(@Param("coupleId") UUID coupleId,
                                 @Param("userId") UUID userId,
                                 @Param("since") java.time.Instant since);
}

