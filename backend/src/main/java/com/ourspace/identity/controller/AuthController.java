package com.ourspace.identity.controller;

import com.ourspace.identity.dto.*;
import com.ourspace.common.dto.ErrorResponse;
import com.ourspace.identity.service.IdentityService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.*;
import io.swagger.v3.oas.annotations.responses.*;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping(value = "/api/v1/auth", produces = MediaType.APPLICATION_JSON_VALUE)
@Tag(name = "Authentication")
public class AuthController {
    private final IdentityService identity;
    public AuthController(IdentityService identity) { this.identity = identity; }

    @Operation(summary = "Register an account")
    @ApiResponses({
        @ApiResponse(responseCode = "201", description = "Account created",
                content = @Content(schema = @Schema(implementation = UserResponse.class))),
        @ApiResponse(responseCode = "409", description = "EMAIL_ALREADY_EXISTS",
                content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
        @ApiResponse(responseCode = "422", description = "VALIDATION_ERROR",
                content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    })
    @PostMapping(value = "/register", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<UserResponse> register(@Valid @RequestBody RegisterRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(identity.register(request));
    }

    @Operation(summary = "Login and obtain a Bearer JWT")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "Authenticated",
                content = @Content(schema = @Schema(implementation = LoginResponse.class))),
        @ApiResponse(responseCode = "401", description = "INVALID_CREDENTIALS",
                content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
        @ApiResponse(responseCode = "422", description = "VALIDATION_ERROR",
                content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    })
    @PostMapping(value = "/login", consumes = MediaType.APPLICATION_JSON_VALUE)
    public LoginResponse login(@Valid @RequestBody LoginRequest request) { return identity.login(request); }
}
