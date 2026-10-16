package com.ourspace.backend.common.exception;

import org.springframework.http.HttpStatus;

public class AlreadyPairedException extends ApiException {
    public AlreadyPairedException(String message) {
        super(HttpStatus.CONFLICT, "ALREADY_PAIRED", message);
    }
}
