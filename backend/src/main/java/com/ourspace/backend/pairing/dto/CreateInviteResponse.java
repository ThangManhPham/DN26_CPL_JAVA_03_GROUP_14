package com.ourspace.backend.pairing.dto;

import java.time.Instant;

public class CreateInviteResponse {

    private final String inviteCode;
    private final Instant expiresAt;

    public CreateInviteResponse(String inviteCode, Instant expiresAt) {
        this.inviteCode = inviteCode;
        this.expiresAt = expiresAt;
    }

    public String getInviteCode() {
        return inviteCode;
    }

    public Instant getExpiresAt() {
        return expiresAt;
    }
}
