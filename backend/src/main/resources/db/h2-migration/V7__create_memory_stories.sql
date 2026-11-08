-- V7__create_memory_stories.sql (H2 compatible)
-- Member 4: AI Memory Story for OurSpace Sprint 3

CREATE TABLE memory_stories (
    id UUID PRIMARY KEY,
    couple_id UUID NOT NULL,
    album_id UUID NOT NULL,
    title VARCHAR(200) NOT NULL,
    story TEXT NOT NULL,
    highlights TEXT NOT NULL,
    tone VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_by UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT fk_memory_stories_couple FOREIGN KEY (couple_id) REFERENCES couples(id) ON DELETE CASCADE,
    CONSTRAINT fk_memory_stories_album FOREIGN KEY (album_id) REFERENCES albums(id) ON DELETE CASCADE,
    CONSTRAINT fk_memory_stories_user FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT chk_memory_stories_status CHECK (status IN ('DRAFT', 'SAVED'))
);

CREATE TABLE memory_story_photos (
    story_id UUID NOT NULL,
    photo_id UUID NOT NULL,
    added_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_memory_story_photos PRIMARY KEY (story_id, photo_id),
    CONSTRAINT fk_memory_story_photos_story FOREIGN KEY (story_id) REFERENCES memory_stories(id) ON DELETE CASCADE,
    CONSTRAINT fk_memory_story_photos_photo FOREIGN KEY (photo_id) REFERENCES photos(id) ON DELETE CASCADE
);

CREATE INDEX idx_memory_stories_couple ON memory_stories(couple_id);
CREATE INDEX idx_memory_stories_album ON memory_stories(album_id);
CREATE INDEX idx_memory_story_photos_photo ON memory_story_photos(photo_id);

