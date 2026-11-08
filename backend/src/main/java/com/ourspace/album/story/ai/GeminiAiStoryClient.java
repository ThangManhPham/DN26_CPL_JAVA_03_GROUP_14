package com.ourspace.album.story.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ourspace.album.story.dto.AiGeneratedStoryDto;
import com.ourspace.common.exception.ApiException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;

public class GeminiAiStoryClient implements AiStoryClient {

    private static final Logger log = LoggerFactory.getLogger(GeminiAiStoryClient.class);
    private static final String GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s";

    private final AiStoryProperties properties;
    private final ObjectMapper objectMapper;
    private final HttpClient httpClient;

    public GeminiAiStoryClient(AiStoryProperties properties, ObjectMapper objectMapper) {
        this.properties = properties;
        this.objectMapper = objectMapper;
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofMillis(properties.getTimeoutMs()))
                .build();
    }

    @Override
    public AiGeneratedStoryDto generateStory(String albumTitle, int photoCount, List<String> photoDates, String userNotes) {
        String apiKey = properties.getApiKey();
        if (apiKey == null || apiKey.trim().isEmpty()) {
            throw new ApiException(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "AI_NOT_CONFIGURED",
                    "Dịch vụ AI chưa được cấu hình khóa API trên máy chủ. Vui lòng liên hệ quản trị viên."
            );
        }

        String userPrompt = AiPromptBuilder.buildUserPrompt(albumTitle, photoCount, photoDates, userNotes);
        String url = String.format(GEMINI_API_URL, properties.getModel(), apiKey);

        Map<String, Object> requestPayload = Map.of(
                "system_instruction", Map.of(
                        "parts", List.of(Map.of("text", AiPromptBuilder.SYSTEM_INSTRUCTION))
                ),
                "contents", List.of(
                        Map.of("parts", List.of(Map.of("text", userPrompt)))
                ),
                "generationConfig", Map.of(
                        "response_mime_type", "application/json",
                        "temperature", 0.7,
                        "maxOutputTokens", properties.getMaxTokens()
                )
        );

        try {
            String requestJson = objectMapper.writeValueAsString(requestPayload);
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .header("Content-Type", "application/json")
                    .timeout(Duration.ofMillis(properties.getTimeoutMs()))
                    .POST(HttpRequest.BodyPublishers.ofString(requestJson))
                    .build();

            log.info("Sending memory story request to Gemini AI (model={})", properties.getModel());
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

            int status = response.statusCode();
            if (status == 429) {
                log.warn("Gemini AI rate limited (HTTP 429)");
                throw new ApiException(
                        HttpStatus.TOO_MANY_REQUESTS,
                        "AI_RATE_LIMIT",
                        "Dịch vụ AI đang quá tải hoặc đạt hạn mức gọi. Vui lòng thử lại sau vài phút."
                );
            }

            if (status >= 400) {
                log.error("Gemini AI returned HTTP error code: {}", status);
                throw new ApiException(
                        HttpStatus.BAD_GATEWAY,
                        "AI_PROVIDER_ERROR",
                        "Dịch vụ AI phản hồi lỗi: " + status + ". Vui lòng thử lại sau."
                );
            }

            return parseGeminiResponse(response.body());

        } catch (ApiException ae) {
            throw ae;
        } catch (java.net.http.HttpTimeoutException te) {
            log.error("Gemini AI request timed out");
            throw new ApiException(
                    HttpStatus.GATEWAY_TIMEOUT,
                    "AI_TIMEOUT",
                    "Kết nối tới dịch vụ AI bị quá thời gian phản hồi (" + properties.getTimeoutMs() + "ms). Vui lòng thử lại."
            );
        } catch (Exception e) {
            log.error("Failed to call Gemini AI: {}", e.getMessage());
            throw new ApiException(
                    HttpStatus.INTERNAL_SERVER_ERROR,
                    "AI_CALL_FAILED",
                    "Không thể kết nối tới dịch vụ AI: " + e.getMessage()
            );
        }
    }

    private AiGeneratedStoryDto parseGeminiResponse(String responseJson) {
        try {
            JsonNode root = objectMapper.readTree(responseJson);
            JsonNode textNode = root.path("candidates").path(0)
                    .path("content").path("parts").path(0).path("text");

            if (textNode.isMissingNode() || textNode.asText().isBlank()) {
                throw new ApiException(HttpStatus.BAD_GATEWAY, "AI_INVALID_RESPONSE", "Không nhận được nội dung từ AI.");
            }

            String innerJson = textNode.asText().trim();
            // Clean up possible markdown code fences
            if (innerJson.startsWith("```json")) {
                innerJson = innerJson.substring(7);
            }
            if (innerJson.startsWith("```")) {
                innerJson = innerJson.substring(3);
            }
            if (innerJson.endsWith("```")) {
                innerJson = innerJson.substring(0, innerJson.length() - 3);
            }
            innerJson = innerJson.trim();

            JsonNode storyNode = objectMapper.readTree(innerJson);
            String title = storyNode.path("title").asText("Kỷ niệm ngọt ngào");
            String story = storyNode.path("story").asText("");
            String tone = storyNode.path("tone").asText("warm");

            List<String> highlights = new ArrayList<>();
            JsonNode hlNode = storyNode.path("highlights");
            if (hlNode.isArray()) {
                for (JsonNode item : hlNode) {
                    highlights.add(item.asText());
                }
            }

            if (story.isBlank()) {
                throw new ApiException(HttpStatus.BAD_GATEWAY, "AI_INVALID_RESPONSE", "Câu chuyện do AI sinh ra bị rỗng.");
            }

            return new AiGeneratedStoryDto(title, story, highlights, tone);

        } catch (ApiException ae) {
            throw ae;
        } catch (Exception e) {
            log.error("Failed to parse Gemini response JSON: {}", e.getMessage());
            throw new ApiException(HttpStatus.BAD_GATEWAY, "AI_INVALID_RESPONSE", "Phản hồi từ AI không đúng cấu trúc JSON yêu cầu.");
        }
    }
}

