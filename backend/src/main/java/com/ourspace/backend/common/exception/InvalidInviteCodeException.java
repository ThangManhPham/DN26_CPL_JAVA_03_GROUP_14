package com.ourspace.backend.common.exception;

import org.springframework.http.HttpStatus;

public class InvalidInviteCodeException extends ApiException {
    public InvalidInviteCodeException(String message) {
        super(HttpStatus.BAD_REQUEST, "INVALID_INVITE_CODE", message);
    }
}
