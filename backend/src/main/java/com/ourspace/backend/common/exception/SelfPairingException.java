package com.ourspace.backend.common.exception;

import org.springframework.http.HttpStatus;

public class SelfPairingException extends ApiException {
    public SelfPairingException(String message) {
        super(HttpStatus.BAD_REQUEST, "CANNOT_PAIR_SELF", message);
    }
}
