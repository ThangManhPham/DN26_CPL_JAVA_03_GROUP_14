package com.ourspace.pairing.exception;

import com.ourspace.common.exception.ApiException;
import org.springframework.http.HttpStatus;

public class InvalidInviteCodeException extends ApiException {
    public InvalidInviteCodeException(String message) {
        super(HttpStatus.BAD_REQUEST, "INVALID_INVITE_CODE", message);
    }
}
