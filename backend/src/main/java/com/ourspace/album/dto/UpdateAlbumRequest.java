package com.ourspace.album.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.UUID;

public record UpdateAlbumRequest(
        @NotBlank(message = "Tên album không được để trống")
        @Size(max = 100, message = "Tên album không được vượt quá 100 ký tự")
        String title,

        @Size(max = 500, message = "Mô tả album không được vượt quá 500 ký tự")
        String description,

        UUID coverPhotoId
) {}
