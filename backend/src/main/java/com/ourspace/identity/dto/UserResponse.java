package com.ourspace.identity.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.UUID;

/** Public user contract deliberately excludes password and password hash. */
public record UserResponse(
        @Schema(requiredMode = Schema.RequiredMode.REQUIRED) UUID id,
        @Schema(requiredMode = Schema.RequiredMode.REQUIRED, example = "alex@example.com") String email,
        @Schema(requiredMode = Schema.RequiredMode.REQUIRED, example = "Alex") String displayName,
        @Schema(nullable = true) String avatarKey
) {}
