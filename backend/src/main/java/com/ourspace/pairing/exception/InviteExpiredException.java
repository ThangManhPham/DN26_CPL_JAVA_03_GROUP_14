package com.ourspace.pairing.exception;

import com.ourspace.common.exception.ApiException;
import org.springframework.http.HttpStatus;

public class InviteExpiredException extends ApiException {
    public InviteExpiredException(String message) {
        super(HttpStatus.BAD_REQUEST, "INVITE_EXPIRED", message);
    }
}
