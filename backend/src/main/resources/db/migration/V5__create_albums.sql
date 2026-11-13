CREATE TABLE albums (
    id UUID PRIMARY KEY,
    couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    title VARCHAR(100) NOT NULL,
    description VARCHAR(500),
    cover_photo_id UUID REFERENCES photos(id) ON DELETE SET NULL,
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE album_photos (
    album_id UUID NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
    photo_id UUID NOT NULL REFERENCES photos(id) ON DELETE CASCADE,
    added_at TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (album_id, photo_id)
);

CREATE INDEX idx_albums_couple_created ON albums(couple_id, created_at DESC);
CREATE INDEX idx_album_photos_album_added ON album_photos(album_id, added_at DESC);
CREATE INDEX idx_album_photos_photo_id ON album_photos(photo_id);
