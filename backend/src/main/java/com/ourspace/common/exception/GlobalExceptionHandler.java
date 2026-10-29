package com.ourspace.common.exception;

import com.ourspace.common.dto.ErrorResponse;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

import java.util.HashMap;
import java.util.Map;

/**
 * GlobalExceptionHandler -- Centralized exception handler for all REST controllers.
 *
 * Conforms to API error format defined in docs/05-api-contract.md:
 * {
 *   "code":      "ERROR_CODE",
 *   "message":   "Error message for client",
 *   "details":   { ... },
 *   "requestId": "req_xxx"
 * }
 *
 * Rules:
 * - Do NOT leak stack traces or internal secrets to client responses.
 * - Do NOT catch all exceptions and incorrectly convert them to HTTP 500.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(ApiException.class)
    public ResponseEntity<ErrorResponse> handleApiException(ApiException ex) {
        return ResponseEntity.status(ex.status()).body(ErrorResponse.of(ex.code(), ex.getMessage()));
    }

    @ExceptionHandler(org.springframework.http.converter.HttpMessageNotReadableException.class)
    public ResponseEntity<ErrorResponse> handleUnreadableBody() {
        return ResponseEntity.badRequest().body(ErrorResponse.of("INVALID_REQUEST",
                "Request body must be valid JSON with only supported fields."));
    }

    @ExceptionHandler(org.springframework.web.HttpMediaTypeNotAcceptableException.class)
    public ResponseEntity<Void> handleNotAcceptable() {
        return ResponseEntity.status(HttpStatus.NOT_ACCEPTABLE).build();
    }

    @ExceptionHandler(org.springframework.orm.ObjectOptimisticLockingFailureException.class)
    public ResponseEntity<ErrorResponse> handleConcurrentUpdate() {
        return ResponseEntity.status(HttpStatus.CONFLICT).body(ErrorResponse.of(
                "PROFILE_CONFLICT", "Profile changed concurrently. Reload and retry."));
    }

    /**
     * Handles validation errors (@Valid on request body).
     * HTTP 422 Unprocessable Entity.
     */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidationErrors(
            MethodArgumentNotValidException ex,
            HttpServletRequest request) {

        String requestId = ErrorResponse.generateRequestId();
        Map<String, Object> fieldErrors = new HashMap<>();
        ex.getBindingResult().getFieldErrors().forEach(fe ->
                fieldErrors.put(fe.getField(), fe.getDefaultMessage() != null ? fe.getDefaultMessage() : "Invalid value")
        );

        log.warn("Validation failed [requestId={}] for {}: {}", requestId, request.getRequestURI(), fieldErrors);

        return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY)
                .body(new ErrorResponse(
                        "VALIDATION_ERROR",
                        "Request contains invalid fields.",
                        fieldErrors,
                        requestId
                ));
    }

    /**
     * Handles 404 when static resource or endpoint path is not found.
     * Prevents Spring from turning missing endpoints into HTTP 500.
     */
    @ExceptionHandler(NoResourceFoundException.class)
    public ResponseEntity<ErrorResponse> handleNoResourceFound(
            NoResourceFoundException ex,
            HttpServletRequest request) {

        String requestId = ErrorResponse.generateRequestId();
        log.warn("Resource not found [requestId={}] for {}: {}", requestId, request.getRequestURI(), ex.getMessage());

        return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(new ErrorResponse(
                        "RESOURCE_NOT_FOUND",
                        "The requested path was not found on this server.",
                        Map.of("resourcePath", ex.getResourcePath()),
                        requestId
                ));
    }

    /**
     * Handles 405 Method Not Allowed (e.g., GET on a POST endpoint).
     */
    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    public ResponseEntity<ErrorResponse> handleMethodNotSupported(
            HttpRequestMethodNotSupportedException ex,
            HttpServletRequest request) {

        String requestId = ErrorResponse.generateRequestId();
        log.warn("Method not supported [requestId={}] for {}: {}", requestId, request.getRequestURI(), ex.getMessage());

        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED)
                .body(new ErrorResponse(
                        "METHOD_NOT_ALLOWED",
                        "HTTP method " + ex.getMethod() + " is not supported for this endpoint.",
                        Map.of("supportedMethods", ex.getSupportedHttpMethods() != null ? ex.getSupportedHttpMethods().toString() : "N/A"),
                        requestId
                ));
    }

    /**
     * Handles 415 Unsupported Media Type.
     */
    @ExceptionHandler(HttpMediaTypeNotSupportedException.class)
    public ResponseEntity<ErrorResponse> handleMediaTypeNotSupported(
            HttpMediaTypeNotSupportedException ex,
            HttpServletRequest request) {

        String requestId = ErrorResponse.generateRequestId();
        log.warn("Media type not supported [requestId={}] for {}: {}", requestId, request.getRequestURI(), ex.getMessage());

        return ResponseEntity.status(HttpStatus.UNSUPPORTED_MEDIA_TYPE)
                .body(new ErrorResponse(
                        "UNSUPPORTED_MEDIA_TYPE",
                        "Unsupported media type. Please send application/json.",
                        Map.of(),
                        requestId
                ));
    }

    /**
     * Handles Spring Security AccessDeniedException (HTTP 403).
     */
    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ErrorResponse> handleAccessDenied(
            AccessDeniedException ex,
            HttpServletRequest request) {

        String requestId = ErrorResponse.generateRequestId();
        log.warn("Access denied [requestId={}] for {}: {}", requestId, request.getRequestURI(), ex.getMessage());

        return ResponseEntity.status(HttpStatus.FORBIDDEN)
                .body(new ErrorResponse(
                        "FORBIDDEN",
                        "Access is denied. You do not have permission to access this resource.",
                        Map.of(),
                        requestId
                ));
    }

    /**
     * Handles Spring Security AuthenticationException (HTTP 401).
     */
    @ExceptionHandler(AuthenticationException.class)
    public ResponseEntity<ErrorResponse> handleAuthenticationException(
            AuthenticationException ex,
            HttpServletRequest request) {

        String requestId = ErrorResponse.generateRequestId();
        log.warn("Authentication failed [requestId={}] for {}: {}", requestId, request.getRequestURI(), ex.getMessage());

        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body(new ErrorResponse(
                        "UNAUTHORIZED",
                        "Authentication is required to access this resource.",
                        Map.of(),
                        requestId
                ));
    }

    /**
     * Handles explicitly thrown ResponseStatusException (e.g. 501 Not Implemented, 400 Bad Request).
     */
    @ExceptionHandler(ResponseStatusException.class)
    public ResponseEntity<ErrorResponse> handleResponseStatusException(
            ResponseStatusException ex,
            HttpServletRequest request) {

        String requestId = ErrorResponse.generateRequestId();
        log.warn("Response status exception [requestId={}] for {}: {}", requestId, request.getRequestURI(), ex.getReason());

        String code = ex.getStatusCode().toString().replace(" ", "_").toUpperCase();
        return ResponseEntity.status(ex.getStatusCode())
                .body(new ErrorResponse(
                        code,
                        ex.getReason() != null ? ex.getReason() : "Request failed.",
                        Map.of(),
                        requestId
                ));
    }

    @ExceptionHandler(org.springframework.dao.DataIntegrityViolationException.class)
    public ResponseEntity<ErrorResponse> handleDataIntegrityViolation(
            org.springframework.dao.DataIntegrityViolationException ex,
            HttpServletRequest request) {

        String requestId = ErrorResponse.generateRequestId();
        log.warn("Data integrity violation [requestId={}] for {}: {}", requestId, request.getRequestURI(), ex.getMessage());

        if (ex.getMessage() != null && ex.getMessage().contains("uq_one_active_couple_per_user")) {
            return ResponseEntity.status(HttpStatus.CONFLICT)
                    .body(new ErrorResponse(
                            "ALREADY_PAIRED",
                            "Người dùng đã thuộc về một cặp đôi đang hoạt động.",
                            Map.of(),
                            requestId
                    ));
        }

        return ResponseEntity.status(HttpStatus.CONFLICT)
                .body(new ErrorResponse(
                        "DATA_CONFLICT",
                        "Xung đột dữ liệu hoặc vi phạm ràng buộc cơ sở dữ liệu.",
                        Map.of(),
                        requestId
                ));
    }

    /**
     * Fallback for any unhandled unexpected exception (HTTP 500).
     * Server-side full stack trace is logged, but NO stack trace or internal
     * information is exposed to the client response.
     */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleGenericException(
            Exception ex,
            HttpServletRequest request) {

        String requestId = ErrorResponse.generateRequestId();
        // Exception messages/SQL values can contain credentials or private data.
        log.error("Unhandled exception [requestId={}] for {} type={}", requestId, request.getRequestURI(), ex.getClass().getName());

        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new ErrorResponse(
                        "INTERNAL_SERVER_ERROR",
                        "An unexpected error occurred. Please try again later.",
                        Map.of(),
                        requestId
                ));
    }
}
