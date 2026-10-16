package com.ourspace.backend.common.exception;

import org.springframework.http.HttpStatus;

public class InviterAlreadyPairedException extends ApiException {
    public InviterAlreadyPairedException(String message) {
        super(HttpStatus.CONFLICT, "INVITER_ALREADY_PAIRED", message);
    }
}
