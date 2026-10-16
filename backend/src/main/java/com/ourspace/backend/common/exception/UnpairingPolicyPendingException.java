package com.ourspace.backend.common.exception;

import org.springframework.http.HttpStatus;

/**
 * Thrown when unpairing is requested but team policy decision OD-03 is pending.
 */
public class UnpairingPolicyPendingException extends ApiException {
    public UnpairingPolicyPendingException(String message) {
        super(HttpStatus.NOT_IMPLEMENTED, "UNPAIRING_POLICY_PENDING", message);
    }
}
