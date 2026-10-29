package com.ourspace.pairing.exception;

import com.ourspace.common.exception.ApiException;
import org.springframework.http.HttpStatus;

public class CoupleNotFoundException extends ApiException {
    public CoupleNotFoundException(String message) {
        super(HttpStatus.NOT_FOUND, "COUPLE_NOT_FOUND", message);
    }
}
