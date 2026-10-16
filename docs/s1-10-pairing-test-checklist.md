# S1-10: Pairing Test Checklist — Manual Test on 2 Devices

> Test ghép đôi thủ công giữa 2 thiết bị (A và B). Mỗi kịch bản cần test trên cả 2 thiết bị.
> **TODO**: điền Kết quả / Screenshot / Ghi chú sau khi test.

## Môi trường test

| Thông tin | Thiết bị A | Thiết bị B |
|---|---|---|
| Tên thiết bị / Simulator | | |
| Platform (Android/iOS) | | |
| App version | | |
| Mode (Mock/Real API) | | |
| Ngày test | | |
| Người test | | |

## Kịch bản test

### TC-01: Tạo mã mời thành công

**Mục tiêu**: Xác nhận thiết bị A có thể tạo mã mời và hiển thị đúng.

**Các bước**:
1. Đăng nhập trên thiết bị A
2. Từ màn Home, nhấn "Tạo mã mời"
3. Quan sát mã 6 ký tự hiển thị
4. Kiểm tra countdown thời gian hiển thị

**Kết quả mong đợi**: ✅ Mã 6 ký tự hiển thị đúng, countdown hoạt động

| Thiết bị | Kết quả | Screenshot | Ghi chú |
|---|---|---|---|
| A | | | |

---

### TC-02: Nhập mã mời thành công

**Mục tiêu**: Xác nhận thiết bị B nhập mã từ A và ghép đôi thành công.

**Các bước**:
1. Trên thiết bị A: tạo mã mời, copy mã
2. Trên thiết bị B: đăng nhập (tài khoản khác)
3. Từ màn Home, nhấn "Nhập mã mời"
4. Dán/dán mã từ A
5. Nhấn "Xác nhận ghép đôi"

**Kết quả mong đợi**: ✅ Ghép đôi thành công, tự động chuyển sang Couple Home

| Thiết bị | Kết quả | Screenshot | Ghi chú |
|---|---|---|---|
| A | | | |
| B | | | |

---

### TC-03: Mã hết hạn

**Mục tiêu**: Xác nhận app xử lý đúng khi mã hết hạn.

**Các bước**:
1. Trên thiết bị A: tạo mã mời
2. Đợi đến khi countdown về 00:00 (hoặc chờ 10 phút nếu dùng time warp)
3. Trên thiết bị B: nhập mã đã hết hạn

**Kết quả mong đợi**: ✅ Hiển thị lỗi "Mã mời đã hết hạn"

| Thiết bị | Kết quả | Screenshot | Ghi chú |
|---|---|---|---|
| A | | | |
| B | | | |

---

### TC-04: Mã đã được sử dụng

**Mục tiêu**: Xác nhận app không cho phép dùng lại mã đã dùng.

**Các bước**:
1. Trên thiết bị A: tạo mã mời
2. Trên thiết bị B: nhập mã, ghép đôi thành công
3. Lấy lại mã đã dùng (có thể copy từ log hoặc share lại mã)
4. Trên thiết bị C (tài khoản thứ 3 - hoặc thoát app B): thử nhập lại mã

**Kết quả mong đợi**: ✅ Hiển thị lỗi "Mã mời đã được sử dụng"

| Thiết bị | Kết quả | Screenshot | Ghi chú |
|---|---|---|---|
| A | | | |
| B | | | |
| C | | | |

---

### TC-05: Tự nhập mã của chính mình

**Mục tiêu**: Xác nhận app không cho phép tự ghép đôi với chính mình.

**Các bước**:
1. Trên thiết bị A: tạo mã mời
2. Copy mã trên thiết bị A
3. Vẫn trên thiết bị A: nhấn "Nhập mã mời"
4. Dán và xác nhận mã của chính mình

**Kết quả mong đợi**: ✅ Hiển thị lỗi "Bạn không thể ghép đôi với chính mình"

| Thiết bị | Kết quả | Screenshot | Ghi chú |
|---|---|---|---|
| A | | | |

---

### TC-06: Tài khoản đã thuộc một cặp đôi khác

**Mục tiêu**: Xác nhận user đã có couple không thể tạo/nhận mã mời khác.

**Các bước**:
1. Ghép đôi A và B thành công
2. Tạo tài khoản C trên thiết bị C
3. Ghép đôi C với A (A tạo mã mới, C nhập)
4. Trên thiết bị B: thử tạo mã mời mới

**Kết quả mong đợi**: ✅ Hiển thị lỗi "Tài khoản đã thuộc một cặp đôi khác"

| Thiết bị | Kết quả | Screenshot | Ghi chú |
|---|---|---|---|
| A | | | |
| B | | | |
| C | | | |

---

### TC-07: Unpair thành công

**Mục tiêu**: Xác nhận user có thể hủy ghép đôi.

**Các bước**:
1. A và B đã ghép đôi thành công
2. Trên thiết bị A: vào Couple Home
3. Nhấn "Hủy ghép đôi"
4. Xác nhận trong hộp thoại

**Kết quả mong đợi**: ✅ Hủy ghép đôi thành công, quay về màn Home

| Thiết bị | Kết quả | Screenshot | Ghi chú |
|---|---|---|---|
| A | | | |
| B (sau khi refresh) | | | |

---

### TC-08: Couple Home hiển thị đúng

**Mục tiêu**: Xác nhận Couple Home hiển thị đúng thông tin cặp đôi.

**Các bước**:
1. A và B ghép đôi thành công
2. Trên thiết bị A: kiểm tra Couple Home
3. Trên thiết bị B: kiểm tra Couple Home

**Kết quả mong đợi**:
- Hiển thị tên của cả 2 người
- Hiển thị avatar/hình đại diện
- Nút "Hủy ghép đôi" hoạt động

| Thiết bị | Kết quả | Screenshot | Ghi chú |
|---|---|---|---|
| A | | | |
| B | | | |

---

### TC-09: Copy mã mời

**Mục tiêu**: Xác nhận nút copy hoạt động đúng.

**Các bước**:
1. Trên thiết bị A: tạo mã mời
2. Nhấn nút "Copy"
3. Kiểm tra snackbar "Đã copy mã mời!"
4. Paste vào app khác để xác nhận đúng mã

**Kết quả mong đợi**: ✅ Snackbar hiển thị, mã được copy đúng

| Thiết bị | Kết quả | Screenshot | Ghi chú |
|---|---|---|---|
| A | | | |

---

## Tổng kết

| Kịch bản | Trạng thái | Ghi chú |
|---|---|---|
| TC-01 | | |
| TC-02 | | |
| TC-03 | | |
| TC-04 | | |
| TC-05 | | |
| TC-06 | | |
| TC-07 | | |
| TC-08 | | |
| TC-09 | | |

**Tổng số pass**: __/9
**Tổng số fail**: __/9

## Bug tracker

| Bug ID | Mô tả | Mức độ | Đã fix? |
|---|---|---|---|
| | | | |
