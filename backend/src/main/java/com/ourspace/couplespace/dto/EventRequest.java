package com.ourspace.couplespace.dto;

import jakarta.validation.constraints.*;
import java.time.Instant;

public record EventRequest(
    @NotBlank @Size(max=150) String title,
    @Size(max=2000) String description,
    @NotNull Instant startsAt,
    @NotNull Instant endsAt,
    @NotBlank String timezone
) {}
