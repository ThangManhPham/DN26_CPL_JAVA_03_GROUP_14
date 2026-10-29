package com.ourspace.identity.controller;

import com.ourspace.identity.dto.*;
import com.ourspace.identity.service.IdentityService;
import com.ourspace.common.dto.ErrorResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.*;
import io.swagger.v3.oas.annotations.responses.*;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.MediaType;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import java.util.UUID;

@RestController
@RequestMapping(value = "/api/v1/users", produces = MediaType.APPLICATION_JSON_VALUE)
@Tag(name = "Users")
@SecurityRequirement(name = "bearerAuth")
@ApiResponses({
    @ApiResponse(responseCode = "401", description = "UNAUTHORIZED",
            content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
})
public class UserController {
    private final IdentityService identity;
    public UserController(IdentityService identity) { this.identity = identity; }

    @Operation(summary = "Get your profile")
    @GetMapping("/me")
    public UserResponse getMyProfile(@AuthenticationPrincipal Jwt jwt) {
        return identity.profile(UUID.fromString(jwt.getSubject()));
    }

    @Operation(summary = "Update your profile", description = "Only displayName and avatarKey may be changed. Explicit avatarKey:null clears the avatar.")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "Profile updated",
                content = @Content(schema = @Schema(implementation = UserResponse.class))),
        @ApiResponse(responseCode = "422", description = "VALIDATION_ERROR",
                content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    })
    @PatchMapping(value = "/me", consumes = MediaType.APPLICATION_JSON_VALUE)
    public UserResponse updateMyProfile(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody UpdateProfileRequest request) {
        return identity.update(UUID.fromString(jwt.getSubject()), request);
    }
}
