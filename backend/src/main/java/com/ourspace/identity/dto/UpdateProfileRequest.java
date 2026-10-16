package com.ourspace.identity.dto;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonSetter;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.*;

public class UpdateProfileRequest {
    @Size(min = 1, max = 100)
    @Pattern(regexp = "(?s).*\\S.*", message = "Display name must not be blank.")
    private String displayName;
    @Size(max = 512)
    @Schema(nullable = true, description = "Private key under avatars/{your-user-id}/; explicit null clears the avatar.")
    private String avatarKey;
    private boolean displayNamePresent;
    private boolean avatarKeyPresent;

    public String getDisplayName() { return displayName; }
    @JsonSetter
    public void setDisplayName(String value) { displayName = value; displayNamePresent = true; }
    public String getAvatarKey() { return avatarKey; }
    @JsonSetter
    public void setAvatarKey(String value) { avatarKey = value; avatarKeyPresent = true; }
    @JsonIgnore @Schema(hidden = true)
    public boolean isAvatarKeyPresent() { return avatarKeyPresent; }

    @AssertTrue(message = "Provide displayName or avatarKey; displayName cannot be null.")
    @JsonIgnore @Schema(hidden = true)
    public boolean isPatchValid() {
        return (displayNamePresent || avatarKeyPresent) && (!displayNamePresent || displayName != null);
    }
}
