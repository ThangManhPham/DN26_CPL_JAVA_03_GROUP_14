# 10. AI Design, Privacy & Safeguards

## 10.1 Mục tiêu AI

AI phải hỗ trợ **giá trị cụ thể trong sản phẩm** chứ không thêm chatbot chung cho có AI:

- **AI Memory Story (Member 4):** từ tập ảnh/ghi chú người dùng tự chọn → câu chuyện kỷ niệm có thể sửa và lưu.
- **AI Date Planner (Member 5):** từ ngân sách/thời lượng/sở thích/khu vực → kế hoạch hẹn hò gợi ý có thể sửa, lưu và chuyển thành sự kiện.

Không cần tự train model. Backend điều phối prompt, rate limiting, validation và storage; client không gọi AI provider trực tiếp bằng key riêng.

## 10.2 Memory Story sequence

1. User mở album → chọn ảnh và ghi chú được phép xử lý.
2. UI giải thích dữ liệu nào sẽ gửi sang AI; user chủ động xác nhận.
3. Spring Boot kiểm tra user thuộc couple, ảnh thuộc album/couple và consent.
4. Chuẩn hóa input có giới hạn; có thể chỉ gửi caption/metadata nếu không cần gửi pixel ảnh.
5. AI trả `title`, `story`, `highlights` theo schema; backend validate, giới hạn độ dài.
6. Hiển thị **Draft**, người dùng chỉnh sửa; chỉ khi bấm Lưu thì thành nội dung couple.

**Structured output đề xuất:**

```json
{
  "title": "Tháng 10 của chúng mình",
  "story": "...",
  "highlights": ["Buổi hẹn đầu tiên", "Cuộc dạo chơi cuối tuần"],
  "tone": "warm"
}
```

AI không tự khẳng định sự kiện không có trong input; lời kể do AI tạo có thể sai nên user phải duyệt.

## 10.3 Date Planner sequence

1. User nhập khu vực, ngân sách (đơn vị tiền), thời lượng, sở thích, hạn chế.
2. Backend validate và gửi dữ liệu tối thiểu cho AI.
3. AI trả `summary`, `activities` (start time dự kiến, mô tả, estimated cost) và `notes`.
4. App hiển thị là **gợi ý chưa xác minh**; người dùng sửa và lưu plan.
5. Nếu muốn đề xuất địa điểm cụ thể/giờ mở cửa chính xác, phải tích hợp nguồn dữ liệu địa điểm đáng tin cậy trước khi hiển thị là thông tin đã xác nhận.

## 10.4 AI integration contract

- Server giữ provider API key trong secret manager/env, không đưa vào Flutter.
- Rate limit/cost caps theo user và feature; timeout, retry giới hạn, request size cap.
- Validate JSON/schema; model failure → thông báo lỗi, cho thử lại khi hợp lý.
- No automatic sending, posting, booking, or tagging partner.
- Có thể lưu provider/model name, latency/token usage để đánh giá cost; tránh raw private prompts nếu không cần.

## 10.5 Privacy & access control

- Images/private notes chỉ truy cập bởi authenticated active couple member.
- Không cấp permanent public URL cho ảnh; ký URL hết hạn ngắn hoặc streaming qua endpoint bảo vệ.
- Consent đối với AI **theo từng lần tác vụ**; thông báo về dữ liệu truyền cho nhà cung cấp.
- Hạn chế prompt chứa PII, tọa độ chính xác, nội dung chat/album không được chọn.
- Khi unpair: phải định nghĩa policy giữ, ẩn, xuất hoặc xóa dữ liệu hai bên (Open Decision OD-03).
- Không lấy suy đoán AI về tình cảm, mức độ chung thủy, nguy cơ chia tay từ ảnh/chat; không tự động phân tích đối phương.
- Đặt secret ngoài repo; logs loại bỏ token, mã invite, raw prompt, nội dung ảnh.

## 10.6 Kiểm thử AI

| Test | Expected |
|---|---|
| Consent = false/missing | Không gọi model |
| Ảnh ngoài couple | 403/404 |
| Input quá dài | 4xx có mô tả lỗi |
| JSON trả về sai schema | Không lưu as final; fallback |
| Provider timeout/429 | App hiển thị retry-safe error |
| Output địa điểm chưa xác minh | Có nhãn gợi ý, không khẳng định đã đặt/đang mở |
| User chỉnh sửa draft | Final phản ánh nội dung user duyệt |
