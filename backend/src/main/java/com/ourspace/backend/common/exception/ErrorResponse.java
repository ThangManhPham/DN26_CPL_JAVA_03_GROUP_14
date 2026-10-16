package com.ourspace.backend.common.exception;

import java.util.Map;

/**
 * Standardized API error response format according to docs/05-api-contract.md.
 */
public class ErrorResponse {

    private final String code;
    private final String message;
    private final Map<String, Object> details;
    private final String requestId;

    public ErrorResponse(String code, String message, Map<String, Object> details, String requestId) {
        this.code = code;
        this.message = message;
        this.details = details != null ? details : Map.of();
        this.requestId = requestId;
    }

    public String getCode() {
        return code;
    }

    public String getMessage() {
        return message;
    }

    public Map<String, Object> getDetails() {
        return details;
    }

    public String getRequestId() {
        return requestId;
    }
}
