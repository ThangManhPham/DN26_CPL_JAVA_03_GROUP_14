package com.ourspace.backend.pairing.dto;

import com.ourspace.backend.pairing.entity.CoupleStatus;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public class CoupleResponse {

    private final UUID id;
    private final CoupleStatus status;
    private final LocalDate anniversaryDate;
    private final List<CoupleMemberResponse> members;
    private final Instant createdAt;

    public CoupleResponse(UUID id, CoupleStatus status, LocalDate anniversaryDate, List<CoupleMemberResponse> members, Instant createdAt) {
        this.id = id;
        this.status = status;
        this.anniversaryDate = anniversaryDate;
        this.members = members != null ? members : List.of();
        this.createdAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public CoupleStatus getStatus() {
        return status;
    }

    public LocalDate getAnniversaryDate() {
        return anniversaryDate;
    }

    public List<CoupleMemberResponse> getMembers() {
        return members;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
