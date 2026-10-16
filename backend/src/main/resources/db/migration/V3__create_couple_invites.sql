-- V3__create_couple_invites.sql
-- Table: couple_invites

CREATE TABLE IF NOT EXISTS couple_invites (
    id UUID PRIMARY KEY,
    inviter_id UUID NOT NULL,
    code_hash VARCHAR(255) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    accepted_by UUID,
    accepted_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_couple_invites_inviter FOREIGN KEY (inviter_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_couple_invites_accepted_by FOREIGN KEY (accepted_by) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT chk_couple_invites_status CHECK (status IN ('PENDING', 'ACCEPTED', 'EXPIRED', 'REVOKED'))
);

CREATE INDEX IF NOT EXISTS idx_couple_invites_code_hash ON couple_invites(code_hash);
CREATE INDEX IF NOT EXISTS idx_couple_invites_inviter_status ON couple_invites(inviter_id, status);
