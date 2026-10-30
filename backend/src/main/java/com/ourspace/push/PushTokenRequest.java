package com.ourspace.push;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record PushTokenRequest(
        @NotBlank @Size(min = 20, max = 1024) String token,
        @NotBlank @Pattern(regexp = "android|ios") String platform) {}
