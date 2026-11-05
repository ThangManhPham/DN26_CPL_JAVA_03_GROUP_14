CREATE TABLE photos (
    id UUID PRIMARY KEY,
    couple_id UUID NOT NULL REFERENCES couples(id),
    sender_id UUID NOT NULL REFERENCES users(id),
    client_request_id UUID NOT NULL,
    storage_key VARCHAR(100) NOT NULL UNIQUE,
    mime_type VARCHAR(30) NOT NULL,
    size_bytes BIGINT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT uq_photos_sender_request UNIQUE (sender_id, client_request_id),
    CONSTRAINT chk_photos_size CHECK (size_bytes > 0 AND size_bytes <= 10485760)
);
CREATE INDEX idx_photos_couple_created ON photos(couple_id, created_at DESC);
