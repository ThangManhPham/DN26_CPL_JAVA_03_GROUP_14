package com.ourspace.album.story.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ourspace.album.story.dto.AiGeneratedStoryDto;
import com.ourspace.common.exception.ApiException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.net.http.HttpTimeoutException;
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
        this(properties, objectMapper, HttpClient.newBuilder()
                .connectTimeout(Duration.ofMillis(properties.getTimeoutMs()))
                .build());
    }

    public GeminiAiStoryClient(AiStoryProperties properties, ObjectMapper objectMapper, HttpClient httpClient) {
        this.properties = properties;
        this.objectMapper = objectMapper;
        this.httpClient = httpClient;
    }

    @Override
    public AiGeneratedStoryDto generateStory(String albumTitle, int photoCount, List<String> photoDates, String userNotes, String requestedTone) {
        String apiKey = properties.getApiKey();
        if (apiKey == null || apiKey.trim().isEmpty()) {
            throw new ApiException(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "AI_NOT_CONFIGURED",
                    "Dịch vụ AI chưa được cấu hình khóa API trên máy chủ. Vui lòng liên hệ quản trị viên."
            );
        }

        String userPrompt = AiPromptBuilder.buildUserPrompt(albumTitle, photoCount, photoDates, userNotes, requestedTone);
        String url = String.format(GEMINI_API_URL, properties.getModel(), apiKey);

        Map<String, Object> requestPayload = Map.of(
                "contents", List.of(
                        Map.of(
                                "role", "user",
                                "parts", List.of(Map.of("text", userPrompt))
                        )
                ),
                "systemInstruction", Map.of(
                        "parts", List.of(Map.of("text", AiPromptBuilder.SYSTEM_INSTRUCTION))
                ),
                "generationConfig", Map.of(
                        "response_mime_type", "application/json",
                        "temperature", 0.7,
                        "maxOutputTokens", properties.getMaxTokens()
                )
        );

        try {
            String requestBody = objectMapper.writeValueAsString(requestPayload);

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .header("Content-Type", "application/json")
                    .timeout(Duration.ofMillis(properties.getTimeoutMs()))
                    .POST(HttpRequest.BodyPublishers.ofString(requestBody))
                    .build();

            log.info("Sending request to Gemini AI (model: {})", properties.getModel());

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            int status = response.statusCode();

            if (status == 429) {
                log.warn("Gemini AI returned 429 Too Many Requests");
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
                        "Dịch vụ AI phản hồi lỗi: HTTP " + status + ". Vui lòng thử lại sau."
                );
            }

            return parseGeminiResponse(response.body(), requestedTone);

        } catch (ApiException ae) {
            throw ae;
        } catch (HttpTimeoutException te) {
            log.error("Gemini AI request timed out");
            throw new ApiException(
                    HttpStatus.GATEWAY_TIMEOUT,
                    "AI_TIMEOUT",
                    "Kết nối tới dịch vụ AI bị quá thời gian phản hồi (" + properties.getTimeoutMs() + "ms). Vui lòng thử lại."
            );
        } catch (Exception e) {
            // Do not log or leak exception message containing URL with API key
            log.error("Failed to call Gemini AI: communication error");
            throw new ApiException(
                    HttpStatus.INTERNAL_SERVER_ERROR,
                    "AI_CALL_FAILED",
                    "Không thể kết nối tới dịch vụ AI. Vui lòng thử lại sau."
            );
        }
    }

    public AiGeneratedStoryDto parseGeminiResponse(String responseJson, String requestedTone) {
        try {
            JsonNode root = objectMapper.readTree(responseJson);
            JsonNode textNode = root.path("candidates").path(0)
                    .path("content").path("parts").path(0).path("text");

            if (textNode.isMissingNode() || textNode.asText().isBlank()) {
                throw new ApiException(HttpStatus.BAD_GATEWAY, "AI_INVALID_RESPONSE", "Không nhận được nội dung từ AI.");
            }

            String innerJson = textNode.asText().trim();
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
            if (!storyNode.isObject()) {
                throw new ApiException(HttpStatus.BAD_GATEWAY, "AI_INVALID_RESPONSE", "Phản hồi AI không phải là JSON Object.");
            }

            // Required field: title
            JsonNode titleNode = storyNode.get("title");
            if (titleNode == null || !titleNode.isTextual() || titleNode.asText().trim().isEmpty()) {
                throw new ApiException(HttpStatus.BAD_GATEWAY, "AI_INVALID_RESPONSE", "Phản hồi AI thiếu trường 'title' hoặc rỗng.");
            }
            String title = titleNode.asText().trim();
            if (title.length() > 200) {
                title = title.substring(0, 200).trim();
            }

            // Required field: story
            JsonNode storyTextNode = storyNode.get("story");
            if (storyTextNode == null || !storyTextNode.isTextual() || storyTextNode.asText().trim().isEmpty()) {
                throw new ApiException(HttpStatus.BAD_GATEWAY, "AI_INVALID_RESPONSE", "Phản hồi AI thiếu trường 'story' hoặc rỗng.");
            }
            String story = storyTextNode.asText().trim();
            if (story.length() > 5000) {
                story = story.substring(0, 5000).trim();
            }

            // Highlights: must be array with 1 to 5 items
            JsonNode hlNode = storyNode.get("highlights");
            if (hlNode == null || !hlNode.isArray()) {
                throw new ApiException(HttpStatus.BAD_GATEWAY, "AI_INVALID_RESPONSE", "Phản hồi AI thiếu trường 'highlights' dạng mảng.");
            }
            List<String> highlights = new ArrayList<>();
            for (JsonNode item : hlNode) {
                if (item.isTextual() && !item.asText().isBlank()) {
                    String hl = item.asText().trim();
                    if (hl.length() > 200) hl = hl.substring(0, 200);
                    highlights.add(hl);
                    if (highlights.size() >= 5) break;
                }
            }
            if (highlights.isEmpty()) {
                highlights.add("Khoảnh khắc đáng nhớ");
            }

            // Tone
            String tone = (requestedTone != null && !requestedTone.isBlank()) ? requestedTone.trim().toUpperCase() : "ROMANTIC";
            JsonNode toneNode = storyNode.get("tone");
            if (toneNode != null && toneNode.isTextual() && !toneNode.asText().isBlank()) {
                String genTone = toneNode.asText().trim().toUpperCase();
                if (genTone.length() <= 50) tone = genTone;
            }

            return new AiGeneratedStoryDto(title, story, highlights, tone);

        } catch (ApiException ae) {
            throw ae;
        } catch (Exception e) {
            log.error("Failed to parse Gemini response JSON");
            throw new ApiException(HttpStatus.BAD_GATEWAY, "AI_INVALID_RESPONSE", "Phản hồi từ AI không đúng cấu trúc JSON yêu cầu.");
        }
    }
}
