package com.ourspace.backend.common.exception;

import jakarta.servlet.http.HttpServletRequest;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(ApiException.class)
    public ResponseEntity<ErrorResponse> handleApiException(ApiException ex, HttpServletRequest request) {
        String requestId = resolveRequestId(request);
        log.warn("API Exception [{}]: {} (requestId: {})", ex.getCode(), ex.getMessage(), requestId);
        ErrorResponse body = new ErrorResponse(ex.getCode(), ex.getMessage(), Map.of(), requestId);
        return ResponseEntity.status(ex.getStatus()).body(body);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidationException(MethodArgumentNotValidException ex, HttpServletRequest request) {
        String requestId = resolveRequestId(request);
        Map<String, Object> details = new HashMap<>();
        for (FieldError fieldError : ex.getBindingResult().getFieldErrors()) {
            details.put(fieldError.getField(), fieldError.getDefaultMessage());
        }
        ErrorResponse body = new ErrorResponse(
                "VALIDATION_ERROR",
                "Dữ liệu gửi lên không hợp lệ.",
                details,
                requestId
        );
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body);
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<ErrorResponse> handleDataIntegrityViolation(DataIntegrityViolationException ex, HttpServletRequest request) {
        String requestId = resolveRequestId(request);
        log.error("Database constraint violation (requestId: {})", requestId, ex);
        // Specifically map race-condition partial unique constraint on active couple membership
        if (ex.getMessage() != null && ex.getMessage().contains("uq_one_active_couple_per_user")) {
            ErrorResponse body = new ErrorResponse(
                    "ALREADY_PAIRED",
                    "Người dùng đã thuộc về một cặp đôi đang hoạt động.",
                    Map.of(),
                    requestId
            );
            return ResponseEntity.status(HttpStatus.CONFLICT).body(body);
        }

        ErrorResponse body = new ErrorResponse(
                "DATA_INTEGRITY_CONFLICT",
                "Xung đột dữ liệu hoặc vi phạm ràng buộc cơ sở dữ liệu.",
                Map.of(),
                requestId
        );
        return ResponseEntity.status(HttpStatus.CONFLICT).body(body);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleGenericException(Exception ex, HttpServletRequest request) {
        String requestId = resolveRequestId(request);
        log.error("Unhandled internal server error (requestId: {})", requestId, ex);
        ErrorResponse body = new ErrorResponse(
                "INTERNAL_SERVER_ERROR",
                "Đã xảy ra lỗi hệ thống. Vui lòng thử lại sau.",
                Map.of(),
                requestId
        );
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(body);
    }

    private String resolveRequestId(HttpServletRequest request) {
        String header = request.getHeader("X-Request-Id");
        if (header != null && !header.isBlank()) {
            return header;
        }
        return "req_" + UUID.randomUUID().toString().substring(0, 8);
    }
}
