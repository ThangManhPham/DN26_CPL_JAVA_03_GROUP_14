package com.ourspace.album.story.ai;

import com.ourspace.album.story.dto.AiGeneratedStoryDto;
import java.util.List;

public class MockAiStoryClient implements AiStoryClient {

    @Override
    public AiGeneratedStoryDto generateStory(String albumTitle, int photoCount, List<String> photoDates, String userNotes, String requestedTone) {
        String effectiveTone = (requestedTone != null && !requestedTone.isBlank()) ? requestedTone.trim().toUpperCase() : "ROMANTIC";
        String title = albumTitle != null && !albumTitle.isBlank()
                ? "Kỷ niệm " + albumTitle
                : "Khoảnh khắc yêu thương của chúng mình";

        String story = "Những kỷ niệm tuyệt vời được lưu giữ qua " + photoCount + " bức ảnh thân thương. "
                + (userNotes != null && !userNotes.isBlank() ? "Với lời nhắn gửi: '" + userNotes + "'. " : "")
                + "Từng nụ cười, từng ánh mắt trao nhau đã dệt nên một câu chuyện tình yêu dịu dàng, ngọt ngào và bền chặt qua năm tháng.";

        List<String> highlights = List.of(
                "Khoảnh khắc ngọt ngào bên nhau",
                "Ánh mắt ấm áp đong đầy yêu thương",
                "Cùng nhau lưu giữ từng giây phút đáng nhớ"
        );

        return new AiGeneratedStoryDto(title, story, highlights, effectiveTone);
    }
}
