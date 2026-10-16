package com.ourspace.backend.common.exception;

import org.springframework.http.HttpStatus;

public class InviteExpiredException extends ApiException {
    public InviteExpiredException(String message) {
        super(HttpStatus.BAD_REQUEST, "INVITE_EXPIRED", message);
    }
}
