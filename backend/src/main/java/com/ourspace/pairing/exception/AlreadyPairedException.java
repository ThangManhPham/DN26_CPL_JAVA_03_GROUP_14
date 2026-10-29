package com.ourspace.pairing.exception;

import com.ourspace.common.exception.ApiException;
import org.springframework.http.HttpStatus;

public class AlreadyPairedException extends ApiException {
    public AlreadyPairedException(String message) {
        super(HttpStatus.CONFLICT, "ALREADY_PAIRED", message);
    }
}
