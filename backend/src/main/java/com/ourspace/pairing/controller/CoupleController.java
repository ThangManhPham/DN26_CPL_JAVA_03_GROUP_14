package com.ourspace.pairing.controller;

import com.ourspace.common.dto.ErrorResponse;
import com.ourspace.pairing.dto.CoupleResponse;
import com.ourspace.pairing.service.CoupleService;
import com.ourspace.security.SecurityUtils;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.UUID;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping(value = "/api/v1/couples", produces = MediaType.APPLICATION_JSON_VALUE)
@Tag(name = "Couples", description = "Couple lifecycle management APIs")
@SecurityRequirement(name = "bearerAuth")
@ApiResponses({
        @ApiResponse(responseCode = "401", description = "UNAUTHORIZED",
                content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
})
public class CoupleController {

    private final CoupleService coupleService;

    public CoupleController(CoupleService coupleService) {
        this.coupleService = coupleService;
    }

    @Operation(summary = "Get current authenticated couple details")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Couple retrieved successfully"),
            @ApiResponse(responseCode = "404", description = "User is not currently in an active couple",
                    content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    })
    @GetMapping("/me")
    public ResponseEntity<CoupleResponse> getMyCouple(Authentication authentication) {
        UUID userId = SecurityUtils.resolveUserId(authentication);
        CoupleResponse response = coupleService.getCurrentCouple(userId);
        return ResponseEntity.ok(response);
    }

    @Operation(summary = "Unpair from current couple (Pending policy OD-03)")
    @ApiResponses({
            @ApiResponse(responseCode = "501", description = "Operation blocked pending OD-03 policy decision",
                    content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
            @ApiResponse(responseCode = "404", description = "User is not currently in an active couple",
                    content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
    })
    @DeleteMapping("/me")
    public ResponseEntity<Void> unpairMyCouple(Authentication authentication) {
        UUID userId = SecurityUtils.resolveUserId(authentication);
        coupleService.unpair(userId);
        return ResponseEntity.noContent().build();
    }
}
