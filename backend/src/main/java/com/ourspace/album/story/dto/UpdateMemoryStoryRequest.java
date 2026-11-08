package com.ourspace.album.story.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.List;

public record UpdateMemoryStoryRequest(
        @NotBlank(message = "Tiêu đề không được để trống")
        @Size(max = 200, message = "Tiêu đề không được vượt quá 200 ký tự")
        String title,

        @NotBlank(message = "Nội dung câu chuyện không được để trống")
        @Size(max = 5000, message = "Nội dung câu chuyện không được vượt quá 5000 ký tự")
        String story,

        List<String> highlights,

        @Size(max = 50, message = "Tone không được vượt quá 50 ký tự")
        String tone
) {}

