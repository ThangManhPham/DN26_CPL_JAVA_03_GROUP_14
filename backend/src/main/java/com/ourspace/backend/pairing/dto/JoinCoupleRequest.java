package com.ourspace.backend.pairing.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public class JoinCoupleRequest {

    @NotBlank(message = "Mã mời không được để trống.")
    @Size(min = 4, max = 32, message = "Mã mời phải có độ dài từ 4 đến 32 ký tự.")
    private String inviteCode;

    public JoinCoupleRequest() {
    }

    public JoinCoupleRequest(String inviteCode) {
        this.inviteCode = inviteCode;
    }

    public String getInviteCode() {
        return inviteCode;
    }

    public void setInviteCode(String inviteCode) {
        this.inviteCode = inviteCode;
    }
}
