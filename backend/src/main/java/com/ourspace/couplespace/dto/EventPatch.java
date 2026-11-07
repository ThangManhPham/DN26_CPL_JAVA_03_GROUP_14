package com.ourspace.couplespace.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.Instant;

/** OpenAPI shape for a partial update. Runtime merge preserves omitted fields. */
public record EventPatch(
    String title,
    @Schema(nullable=true) String description,
    Instant startsAt,
    Instant endsAt,
    String timezone,
    @Schema(requiredMode=Schema.RequiredMode.REQUIRED,description="Version from the last GET/list; stale writes return 409") Long version
) {}
