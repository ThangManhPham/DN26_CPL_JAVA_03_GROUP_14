package com.ourspace.couplespace.controller;

import com.ourspace.couplespace.dto.*;
import com.ourspace.couplespace.service.CalendarService;
import com.ourspace.security.SecurityUtils;
import com.fasterxml.jackson.databind.JsonNode;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.*;
import com.ourspace.common.dto.ErrorResponse;
import jakarta.validation.Valid;
import org.springframework.http.*;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import java.time.Instant;
import java.util.UUID;

@RestController
@RequestMapping(value="/api/v1",produces=MediaType.APPLICATION_JSON_VALUE)
@Tag(name="Couple Space & Calendar")
@SecurityRequirement(name="bearerAuth")
@ApiResponses({
    @ApiResponse(responseCode="401",description="Missing/invalid Bearer token",content=@Content(schema=@Schema(implementation=ErrorResponse.class))),
    @ApiResponse(responseCode="404",description="No active couple or event outside current couple",content=@Content(schema=@Schema(implementation=ErrorResponse.class))),
    @ApiResponse(responseCode="422",description="Invalid fields, timezone or range",content=@Content(schema=@Schema(implementation=ErrorResponse.class)))
})
public class CalendarController {
    private final CalendarService service;
    public CalendarController(CalendarService service) { this.service=service; }
    @GetMapping("/couple-space")
    @Operation(summary="Get anniversary and elapsed calendar days (start date is day zero)")
    public CalendarService.Space space(Authentication auth,@RequestParam(defaultValue="Asia/Ho_Chi_Minh") String timezone) {
        return service.space(SecurityUtils.resolveUserId(auth),timezone);
    }
    @PatchMapping(value="/couple-space",consumes=MediaType.APPLICATION_JSON_VALUE)
    @Operation(summary="Set shared anniversary date; both active members may update")
    public CalendarService.Space anniversary(Authentication auth,@Valid @RequestBody AnniversaryRequest data,
            @RequestParam(defaultValue="Asia/Ho_Chi_Minh") String timezone) {
        return service.anniversary(SecurityUtils.resolveUserId(auth),data.anniversaryDate(),timezone);
    }
    @GetMapping("/events")
    @Operation(summary="List events overlapping [from, until)",description="UTC instants, range <=366 days, page starts at 0, size 1..100. Follow nextPage until null.")
    public CalendarService.EventPage list(Authentication auth,@RequestParam Instant from,@RequestParam Instant until,
            @RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="50") int size) {
        return service.list(SecurityUtils.resolveUserId(auth),from,until,page,size);
    }
    @PostMapping(value="/events",consumes=MediaType.APPLICATION_JSON_VALUE)
    @ApiResponse(responseCode="201",description="Event created",content=@Content(schema=@Schema(implementation=EventResponse.class)))
    public ResponseEntity<EventResponse> create(Authentication auth,@Valid @RequestBody EventRequest data) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.create(SecurityUtils.resolveUserId(auth),data));
    }
    @GetMapping("/events/{id}")
    public EventResponse get(Authentication auth,@PathVariable UUID id) { return service.get(SecurityUtils.resolveUserId(auth),id); }
    @PatchMapping(value="/events/{id}",consumes=MediaType.APPLICATION_JSON_VALUE)
    @Operation(summary="Update event fields; version required; description:null clears notes",
        requestBody=@io.swagger.v3.oas.annotations.parameters.RequestBody(required=true,
            content=@Content(mediaType="application/json",schema=@Schema(implementation=EventPatch.class))))
    @ApiResponse(responseCode="409",description="EVENT_CONFLICT: reload event before retrying",content=@Content(schema=@Schema(implementation=ErrorResponse.class)))
    public EventResponse patch(Authentication auth,@PathVariable UUID id,@RequestBody JsonNode data) {
        return service.patch(SecurityUtils.resolveUserId(auth),id,data);
    }
    @DeleteMapping("/events/{id}")
    @ApiResponses({@ApiResponse(responseCode="204",description="Event deleted"),
        @ApiResponse(responseCode="409",description="EVENT_CONFLICT: stale version",content=@Content(schema=@Schema(implementation=ErrorResponse.class)))})
    public ResponseEntity<Void> delete(Authentication auth,@PathVariable UUID id,@RequestParam long version) {
        service.delete(SecurityUtils.resolveUserId(auth),id,version);
        return ResponseEntity.noContent().build();
    }
}
