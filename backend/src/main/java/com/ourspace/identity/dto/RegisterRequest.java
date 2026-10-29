package com.ourspace.identity.dto;

import com.fasterxml.jackson.annotation.JsonIgnore;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.*;
import java.nio.charset.StandardCharsets;
import java.util.Locale;

public record RegisterRequest(
        @NotBlank @Email @Size(max = 254) @Schema(example = "alex@example.com") String email,
        @NotBlank @Size(min = 8, max = 72)
        @Schema(format = "password", accessMode = Schema.AccessMode.WRITE_ONLY,
                description = "8 to 72 characters and at most 72 UTF-8 bytes; no trimming.") String password,
        @NotBlank @Size(max = 100) @Schema(example = "Alex") String displayName
) {
    public RegisterRequest {
        if (email != null) email = email.strip().toLowerCase(Locale.ROOT);
    }
    @AssertTrue(message = "Password must be at most 72 UTF-8 bytes.")
    @JsonIgnore @Schema(hidden = true)
    public boolean isPasswordByteLengthValid() {
        return password == null || password.getBytes(StandardCharsets.UTF_8).length <= 72;
    }
    @Override public String toString() { return "RegisterRequest[redacted]"; }
}
