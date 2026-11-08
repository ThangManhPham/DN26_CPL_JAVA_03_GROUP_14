package com.ourspace.album.story.repository;

import com.ourspace.album.story.entity.MemoryStoryPhoto;
import com.ourspace.album.story.entity.MemoryStoryPhotoId;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface MemoryStoryPhotoRepository extends JpaRepository<MemoryStoryPhoto, MemoryStoryPhotoId> {
    List<MemoryStoryPhoto> findByIdStoryId(UUID storyId);
    void deleteByIdStoryId(UUID storyId);
}

