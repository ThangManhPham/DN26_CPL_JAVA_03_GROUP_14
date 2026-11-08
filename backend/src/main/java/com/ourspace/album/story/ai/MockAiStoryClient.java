package com.ourspace.album.story.ai;

import com.ourspace.album.story.dto.AiGeneratedStoryDto;
import java.util.List;

public class MockAiStoryClient implements AiStoryClient {

    @Override
    public AiGeneratedStoryDto generateStory(String albumTitle, int photoCount, List<String> photoDates, String userNotes) {
        String title = (albumTitle != null && !albumTitle.isBlank())
                ? "Kỷ niệm " + albumTitle
                : "Khoảnh khắc ngọt ngào của chúng mình";

        String notesSnippet = (userNotes != null && !userNotes.isBlank())
                ? " Những dòng nhật ký nhắn gửi: \"" + userNotes.trim() + "\"."
                : "";

        String story = "Nhìn lại " + photoCount + " bức ảnh được lưu giữ trong album, mỗi khoảnh khắc đều gợi nhắc về hành trình yêu thương mà hai bạn đã cùng nhau đi qua."
                + notesSnippet
                + " Dù thời gian trôi qua, những nụ cười và kỷ niệm chân thành sẽ luôn là ngọn lửa ấm áp sưởi ấm cho tình yêu của hai bạn.";

        List<String> highlights = List.of(
                "Khoảnh khắc đáng nhớ trong " + (albumTitle != null ? albumTitle : "album"),
                "Lưu giữ " + photoCount + " bức ảnh kỷ niệm",
                "Tình yêu được sẻ chia và trân trọng"
        );

        return new AiGeneratedStoryDto(title, story, highlights, "warm");
    }
}

