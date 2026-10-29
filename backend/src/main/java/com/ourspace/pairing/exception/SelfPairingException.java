package com.ourspace.pairing.exception;

import com.ourspace.common.exception.ApiException;
import org.springframework.http.HttpStatus;

public class SelfPairingException extends ApiException {
    public SelfPairingException(String message) {
        super(HttpStatus.BAD_REQUEST, "CANNOT_PAIR_SELF", message);
    }
}
