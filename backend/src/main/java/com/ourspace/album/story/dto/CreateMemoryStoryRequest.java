package com.ourspace.album.story.dto;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.UUID;

public record CreateMemoryStoryRequest(
        @NotNull(message = "albumId không được để trống")
        UUID albumId,

        @NotEmpty(message = "Phải chọn ít nhất 1 ảnh để tạo câu chuyện")
        @Size(max = 20, message = "Không được chọn quá 20 ảnh cho một câu chuyện")
        List<UUID> selectedPhotoIds,

        @Size(max = 1000, message = "Ghi chú không được vượt quá 1000 ký tự")
        String notes,

        @Size(max = 50, message = "Tone không được vượt quá 50 ký tự")
        String tone,

        @NotNull(message = "Bắt buộc phải có xác nhận đồng ý (consent)")
        Boolean consent
) {}

