package com.ourspace.common.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.util.Collections;
import java.util.Map;
import java.util.UUID;

/**
 * ErrorResponse -- Standard JSON error format defined in docs/05-api-contract.md.
 *
 * Example:
 * {
 *   "code": "INVITE_EXPIRED",
 *   "message": "Mã ghép đôi đã hết hạn.",
 *   "details": {},
 *   "requestId": "req_123"
 * }
 */
@Schema(description = "Standard error response format")
public record ErrorResponse(
        @Schema(description = "Machine-readable error code", example = "NOT_IMPLEMENTED")
        String code,

        @Schema(description = "Human-readable error description", example = "Endpoint not implemented yet.")
        String message,

        @Schema(description = "Additional context or validation field errors")
        Map<String, Object> details,

        @Schema(description = "Unique trace ID for tracking error logs", example = "req_a1b2c3d4e5f6")
        String requestId
) {
    public static ErrorResponse of(String code, String message) {
        return new ErrorResponse(code, message, Collections.emptyMap(), generateRequestId());
    }

    public static ErrorResponse of(String code, String message, Map<String, Object> details) {
        return new ErrorResponse(code, message, details != null ? details : Collections.emptyMap(), generateRequestId());
    }

    public static ErrorResponse of(String code, String message, Map<String, Object> details, String requestId) {
        return new ErrorResponse(code, message, details != null ? details : Collections.emptyMap(), requestId != null ? requestId : generateRequestId());
    }

    public static String generateRequestId() {
        String current = org.slf4j.MDC.get("requestId");
        if (current != null) return current;
        return "req_" + UUID.randomUUID().toString().replace("-", "").substring(0, 12);
    }
}
