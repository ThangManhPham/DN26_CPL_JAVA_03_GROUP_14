package com.ourspace.couplespace.dto;

import com.ourspace.couplespace.entity.CoupleEvent;
import java.time.Instant;
import java.util.UUID;

public record EventResponse(UUID id, UUID coupleId, UUID createdBy, String title, String description,
    Instant startsAt, Instant endsAt, String timezone, long version) {
    public static EventResponse of(CoupleEvent e) {
        return new EventResponse(e.id,e.coupleId,e.createdBy,e.title,e.description,e.startsAt,e.endsAt,e.timezone,e.version);
    }
}
