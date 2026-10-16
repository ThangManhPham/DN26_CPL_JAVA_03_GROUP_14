-- V2__create_couples_and_members.sql
-- Tables: couples, couple_members

CREATE TABLE IF NOT EXISTS couples (
    id UUID PRIMARY KEY,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    anniversary_date DATE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_couples_status CHECK (status IN ('ACTIVE', 'ENDED'))
);

CREATE TABLE IF NOT EXISTS couple_members (
    couple_id UUID NOT NULL,
    user_id UUID NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'MEMBER',
    joined_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    left_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT pk_couple_members PRIMARY KEY (couple_id, user_id),
    CONSTRAINT fk_couple_members_couple FOREIGN KEY (couple_id) REFERENCES couples(id) ON DELETE CASCADE,
    CONSTRAINT fk_couple_members_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT chk_couple_members_role CHECK (role IN ('MEMBER', 'ADMIN'))
);

-- Partial unique index ensuring exactly one active couple membership per user
CREATE UNIQUE INDEX IF NOT EXISTS uq_one_active_couple_per_user
    ON couple_members(user_id)
    WHERE left_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_couple_members_couple_id ON couple_members(couple_id);
CREATE INDEX IF NOT EXISTS idx_couple_members_user_id ON couple_members(user_id);
