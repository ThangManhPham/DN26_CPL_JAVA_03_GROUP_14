package com.ourspace.pairing.dto;

import java.time.Instant;
import java.util.UUID;

public class CoupleMemberResponse {

    private final UUID id;
    private final String displayName;
    private final String email;
    private final String role;
    private final Instant joinedAt;

    public CoupleMemberResponse(UUID id, String displayName, String email, String role, Instant joinedAt) {
        this.id = id;
        this.displayName = displayName;
        this.email = email;
        this.role = role;
        this.joinedAt = joinedAt;
    }

    public UUID getId() {
        return id;
    }

    public String getDisplayName() {
        return displayName;
    }

    public String getEmail() {
        return email;
    }

    public String getRole() {
        return role;
    }

    public Instant getJoinedAt() {
        return joinedAt;
    }
}
