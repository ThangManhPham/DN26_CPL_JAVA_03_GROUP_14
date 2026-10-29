package com.ourspace.identity.dto;

import io.swagger.v3.oas.annotations.media.Schema;

/** Login response. Access tokens are credentials and must not be logged. */
public record LoginResponse(
        @Schema(requiredMode = Schema.RequiredMode.REQUIRED) String accessToken,
        @Schema(requiredMode = Schema.RequiredMode.REQUIRED, example = "Bearer") String tokenType,
        @Schema(requiredMode = Schema.RequiredMode.REQUIRED) UserResponse user
) {
    @Override public String toString() { return "LoginResponse[redacted]"; }
}
