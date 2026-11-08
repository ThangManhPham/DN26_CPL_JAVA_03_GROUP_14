package com.ourspace.album.story.service;

import com.ourspace.album.story.ai.AiStoryProperties;
import com.ourspace.common.exception.ApiException;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

@Component
public class AiStoryRateLimiter {

    private final AiStoryProperties properties;
    private final Map<UUID, UserState> states = new ConcurrentHashMap<>();

    public AiStoryRateLimiter(AiStoryProperties properties) {
        this.properties = properties;
    }

    public void tryAcquire(UUID userId) {
        states.compute(userId, (id, state) -> {
            if (state == null) {
                state = new UserState();
            }

            if (state.inFlight) {
                throw new ApiException(
                        HttpStatus.TOO_MANY_REQUESTS,
                        "AI_SUBMIT_LIMIT_EXCEEDED",
                        "Bạn đang có một yêu cầu tạo câu chuyện đang được xử lý. Vui lòng chờ hoàn tất."
                );
            }

            Instant now = Instant.now();
            long cooldownSeconds = (long) properties.getRateLimitWindowMinutes() * 60L / Math.max(1, properties.getMaxDraftsPerWindow());
            if (cooldownSeconds < 10) cooldownSeconds = 10;

            if (state.lastSuccessTime != null) {
                long elapsed = Duration.between(state.lastSuccessTime, now).toSeconds();
                if (elapsed < cooldownSeconds) {
                    long remaining = cooldownSeconds - elapsed;
                    throw new ApiException(
                            HttpStatus.TOO_MANY_REQUESTS,
                            "AI_SUBMIT_LIMIT_EXCEEDED",
                            "Vui lòng chờ " + remaining + " giây trước khi tạo câu chuyện tiếp theo."
                    );
                }
            }

            state.inFlight = true;
            return state;
        });
    }

    public void releaseOnError(UUID userId) {
        states.computeIfPresent(userId, (id, state) -> {
            state.inFlight = false;
            return state;
        });
    }

    public void complete(UUID userId) {
        states.computeIfPresent(userId, (id, state) -> {
            state.inFlight = false;
            state.lastSuccessTime = Instant.now();
            return state;
        });
    }

    public void resetForTest(UUID userId) {
        states.remove(userId);
    }

    private static class UserState {
        boolean inFlight = false;
        Instant lastSuccessTime = null;
    }
}
