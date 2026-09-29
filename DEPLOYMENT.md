# Thông Tin Deploy — Checkpoint 5

> Điền file này sau khi deploy xong. `pytest tests/test_cp5.py` đọc file này
> để tìm địa chỉ service của bạn và gọi thử.
>
> **Chỉ ghi TÊN biến môi trường, tuyệt đối không dán giá trị API key vào đây.**
> Repo này công khai — dán khóa vào là mất khóa.

## Thông Tin Học Viên

| Mục | Nội dung |
|-----|----------|
| Họ và tên | Đỗ Trung Tuyến |
| Mã học viên | 2A202602427 |
| Repo | https://github.com/TrungTuyenDo02/K4-L3B-DAY12-DoTrungTuyen-2A202602427-CloudServicesAndDeployment |

## Service

| Mục | Nội dung |
|-----|----------|
| Public URL | https://k4-l3b-day12-dotrungtuyen-2a202602427.onrender.com |
| Platform | Render — Web Service (runtime Docker, build từ `Dockerfile`, plan free) + Render Key Value (Redis) |
| Ngày deploy | 29/09/2026 |

## Biến Môi Trường Đã Set Trên Cloud

Ghi tên biến và **nguồn giá trị**, không ghi giá trị:

| Biến | Đã set | Ghi chú |
|------|--------|---------|
| `PORT` | ✅ | platform tự gán |
| `AGENT_API_KEY` | ✅ | đặt trong Render dashboard → Environment, không nằm trong repo |
| `REDIS_URL` | ✅ | Internal URL của Render Key Value (cùng region với web service), đặt trong dashboard → Environment |
| `RATE_LIMIT_PER_MINUTE` | ✅ | 10 |
| `MONTHLY_BUDGET_USD` | ✅ | 10.0 |
| `LOG_LEVEL` | ✅ | INFO |

## Lệnh Kiểm Tra

Thay `<URL>` bằng Public URL ở trên:

```bash
# 1. Liveness — mong đợi 200 {"status":"ok"}
curl -i <URL>/health

# 2. Readiness — mong đợi 200 {"status":"ready"} (đã nối được Redis)
curl -i <URL>/ready

# 3. Không có API key — mong đợi 401
curl -i -X POST <URL>/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"Hello"}'

# 4. Có API key — mong đợi 200 kèm câu trả lời
curl -i -X POST <URL>/ask \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $AGENT_API_KEY" \
  -H "X-User-Id: sv-test" \
  -d '{"question":"Deploy là gì?"}'

# 5. Rate limit — gọi 15 lần, những lần cuối phải trả 429
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code} " -X POST <URL>/ask \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $AGENT_API_KEY" \
    -H "X-User-Id: sv-test" \
    -d '{"question":"test"}'
done; echo
```

## Kết Quả Chạy Thật

Dán output của các lệnh trên vào đây:

Chạy ngày 29/09/2026 (lệnh 1–3, trích status line + body):

```
$ curl -i https://k4-l3b-day12-dotrungtuyen-2a202602427.onrender.com/health
HTTP/1.1 200 OK
{"status":"ok","service":"day12-agent","version":"1.0.0"}

$ curl -i https://k4-l3b-day12-dotrungtuyen-2a202602427.onrender.com/ready
HTTP/1.1 200 OK
{"status":"ready","redis":true}

$ curl -i -X POST https://k4-l3b-day12-dotrungtuyen-2a202602427.onrender.com/ask -H "Content-Type: application/json" -d '{"question":"Hello"}'
HTTP/1.1 401 Unauthorized
{"detail":"invalid or missing API key"}
```

Lệnh 4–5 (key lấy từ biến môi trường, không ghi ra đây):

```
# Lệnh 5 — 15 lần liên tiếp, user sv-test
200 200 200 200 200 200 200 200 200 200 429 429 429 429 429

# Lệnh 4 — sau khi hết cửa sổ 60s, body gửi từ file UTF-8 (--data-binary @body.json)
HTTP/1.1 200 OK
{"answer":"Câu hỏi hay. Deploy là gì thường được giải quyết bằng cách chuẩn hóa môi trường chạy: cùng một image chạy giống nhau ở laptop và trên cloud. (Mình đang nhớ 20 lượt trao đổi trước đó.)","user_id":"sv-test","history_length":20,"cost_usd":9.285e-05,"tokens":{"in":439,"out":45}}
```

Ghi chú: chạy lệnh 4 nguyên văn (`-d '{"question":"Deploy là gì?"}'`) trong Git Bash trên Windows trả
`400 {"detail":"There was an error parsing the body"}` vì chữ tiếng Việt không được gửi dưới dạng UTF-8;
gửi body từ file UTF-8 thì trả 200. `history_length` = 20 vì lịch sử bị cắt còn 20 message gần nhất.

`pytest tests/test_cp5.py -v` (có `DEPLOY_API_KEY` trong `.env` ở máy): **9 passed, 4 skipped** (4 test chỉ dành cho LOCAL_FALLBACK).

Sự cố gặp khi deploy và cách sửa:

| Lần | Triệu chứng | Nguyên nhân | Cách sửa |
|-----|-------------|-------------|----------|
| 1 | `/health` 200 nhưng `/ready` và `/ask` (không key) trả 500 | Chưa set `AGENT_API_KEY` → `Settings` ném `ValidationError` khi `/ready`, `/ask` đọc cấu hình | Thêm `AGENT_API_KEY` trong Environment |
| 2 | `/ask` không key → 401 (đúng), nhưng `/ready` 503 `{"status":"not ready","redis":false}` | `REDIS_URL` trỏ `localhost` — trên Render không có Redis ở localhost | Tạo Render Key Value, đặt `REDIS_URL` = Internal URL, redeploy |
| 3 | `/health` 200, `/ready` 200, `/ask` không key 401 | — | Hoạt động đúng |

## Ảnh Chụp Màn Hình

Đặt ảnh trong thư mục `screenshots/`:

- `screenshots/dashboard.png` — trang quản lý service trên platform
- `screenshots/health.png` — kết quả gọi `/health` từ trình duyệt hoặc curl
