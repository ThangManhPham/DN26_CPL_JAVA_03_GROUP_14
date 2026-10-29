package com.ourspace.pairing.exception;

import com.ourspace.common.exception.ApiException;
import org.springframework.http.HttpStatus;

public class UnpairingPolicyPendingException extends ApiException {
    public UnpairingPolicyPendingException(String message) {
        super(HttpStatus.NOT_IMPLEMENTED, "UNPAIRING_POLICY_PENDING", message);
    }
}
