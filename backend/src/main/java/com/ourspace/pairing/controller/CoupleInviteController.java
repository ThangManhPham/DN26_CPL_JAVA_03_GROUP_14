package com.ourspace.pairing.controller;

import com.ourspace.common.dto.ErrorResponse;
import com.ourspace.pairing.dto.CoupleResponse;
import com.ourspace.pairing.dto.CreateInviteResponse;
import com.ourspace.pairing.dto.JoinCoupleRequest;
import com.ourspace.pairing.service.CoupleInviteService;
import com.ourspace.security.SecurityUtils;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping(value = "/api/v1", produces = MediaType.APPLICATION_JSON_VALUE)
@Tag(name = "Pairing", description = "Couple invitation and pairing APIs")
@SecurityRequirement(name = "bearerAuth")
@ApiResponses({
        @ApiResponse(responseCode = "401", description = "UNAUTHORIZED",
                content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
})
public class CoupleInviteController {

    private final CoupleInviteService coupleInviteService;

    public CoupleInviteController(CoupleInviteService coupleInviteService) {
        this.coupleInviteService = coupleInviteService;
    }

    @Operation(summary = "Generate a new couple invitation code")
    @ApiResponses({
            @ApiResponse(responseCode = "201", description = "Invite code created successfully"),
            @ApiResponse(responseCode = "409", description = "User is already in an active couple",
                    content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    })
    @PostMapping("/couple-invites")
    public ResponseEntity<CreateInviteResponse> createInvite(Authentication authentication) {
        UUID inviterId = SecurityUtils.resolveUserId(authentication);
        CreateInviteResponse response = coupleInviteService.createInvite(inviterId);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @Operation(summary = "Join a couple using an invitation code")
    @ApiResponses({
            @ApiResponse(responseCode = "201", description = "Joined couple successfully"),
            @ApiResponse(responseCode = "400", description = "Invalid code, expired code, or self-pairing attempt",
                    content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
            @ApiResponse(responseCode = "409", description = "Already paired or inviter already paired",
                    content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    })
    @PostMapping(value = "/couples/join", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<CoupleResponse> joinCouple(
            Authentication authentication,
            @Valid @RequestBody JoinCoupleRequest request
    ) {
        UUID joinerId = SecurityUtils.resolveUserId(authentication);
        CoupleResponse response = coupleInviteService.acceptInvite(joinerId, request.getInviteCode());
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }
}
