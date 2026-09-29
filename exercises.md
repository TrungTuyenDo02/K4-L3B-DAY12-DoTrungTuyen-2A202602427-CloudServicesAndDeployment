# K4 Level 3B, Ngày 12

> \*\*Bài làm cá nhân.\*\* Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng `> \*Câu trả lời của bạn\*` bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Đỗ Trung Tuyến  Mã học viên: 2A202602427

\---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent\_api\_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Lần đầu deploy lên Render tôi quên đặt `AGENT\_API\_KEY`. Vì không có mặc định, `Settings` ném `ValidationError: agent\_api\_key Field required` và `/ask` trả 500 thay vì chạy. Nếu mặc định là `"changeme"`, app sẽ lên bình thường với một key ai cũng đoán được → người lạ gọi `/ask` thoải mái, đốt tiền LLM mà tôi không hề biết. Lỗi rõ ràng, chỉ đúng tên trường thiếu, nên tôi sửa được ngay.

\---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> `{"event": "ask\_completed", "level": "info", "timestamp": "2026-09-29T04:14:25.006705+00:00", "user\_id": "sv-obs-rl", "tokens\_in": 1, "tokens\_out": 33, "cost\_usd": 1.995e-05}`
>
> 1. Lọc/đếm theo user: ví dụ `jq 'select(.user\_id=="sv-obs-rl")'` để biết một user gọi bao nhiêu lần, ai đang spam.
> 2. Cộng `cost\_usd`, `tokens\_out` theo user/ngày để theo dõi chi phí, và dùng `timestamp` UTC để ghép log của 3 container theo đúng thứ tự thời gian.
>
> Log cũng không chứa API key hay nội dung câu hỏi nên an toàn khi gửi lên hệ thống log.

\---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

|Bản|Dung lượng|
|-|-|
|1 stage (bản đầu)|1730 MB (1.73GB)|
|Multi-stage|271 MB|

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Bản multi-stage nhỏ hơn khoảng 6,5 lần. Phần chênh \~1,46GB chủ yếu là: base `python:3.11` đầy đủ (gcc, header, công cụ build, tài liệu… chỉ cần lúc cài, không cần lúc chạy) và mọi thứ bị `COPY . .` kéo vào (test, file thừa). Bản multi-stage chỉ lấy base `python:3.11-slim` (189MB) + thư mục thư viện đã cài từ stage builder + code `app/`, `utils/` (\~82MB).

\---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Tôi thêm một dấu `.` vào comment trong `app/main.py` rồi build lại. Bản multi-stage: toàn bộ stage builder (`WORKDIR`, `COPY requirements.txt`, `pip install`) và `COPY --from=builder`, `WORKDIR /app` đều CACHED; chỉ chạy lại `COPY app`, `COPY utils`, `useradd` — mất vài giây. Cache bị hủy từ layer đầu tiên có input thay đổi trở xuống, nên `useradd` đặt sau `COPY app` cũng bị chạy lại (đưa nó lên trước thì sẽ được cache).
>
> Với `Dockerfile.single` (`COPY . .` trước `pip install`): sửa một ký tự làm `COPY . .` đổi → `pip install` chạy lại toàn bộ, mất \~34 giây chỉ vì một comment.

\---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> Chuỗi: lỗ hổng trong code (ví dụ RCE qua `eval`, deserialize, path traversal) → kẻ tấn công chạy lệnh với quyền của process → process là root (uid 0) trong container → sửa được thư viện, cài công cụ, đọc mọi file; uid 0 trong container cũng là uid 0 trên host → chỉ cần thêm một điểm yếu (volume mount từ host, `docker.sock`, container `privileged`, lỗi kernel để escape) là thành root trên host.
>
> `USER appuser` cắt ngay ở bước "process là root": code chạy với uid 10001. Tôi đã kiểm tra: `docker compose exec agent id` → `uid=10001(appuser)`, và `touch /usr/local/lib/thu\_ghi` → `Permission denied`. Dù có lỗ hổng, kẻ tấn công chỉ có quyền user thường, và nếu escape được thì cũng chỉ là user không đặc quyền trên host.

\---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

> Tối đa \*\*20 request\*\*. Gửi 10 request ở giây 59 của phút 12:00 (hợp lệ, phút này mới dùng 10), rồi đồng hồ sang 12:01:00 thì bộ đếm reset, gửi tiếp 10 request nữa ở giây 00. Tổng 20 request trong khoảng 2 giây, gấp đôi hạn mức.
>
> Sliding window 60 giây nhìn lại đúng 60 giây trước mỗi request, nên ở giây 00 nó vẫn thấy 10 request vừa gửi và trả 429. Thực tế tôi đo: 15 request liên tiếp → 10 lần 200 rồi 5 lần 429.

\---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

> Rate limit giới hạn \*\*số request trong một khoảng thời gian ngắn\*\* (10/phút, trả 429) để chống spam/burst. Cost guard giới hạn \*\*tổng tiền đã tiêu trong tháng\*\* của user (trả 402), không quan tâm gọi nhanh hay chậm.
>
> - Rate limit qua, cost guard chặn: user `sv02` đã tiêu 999 USD trong tháng, chỉ gửi 1 request → vẫn còn quota rate limit nhưng nhận `402 monthly budget exceeded`, và bị chặn trước khi gọi LLM nên không tốn thêm tiền.
> - Cost guard qua, rate limit chặn: user gửi 15 câu hỏi ngắn trong một phút, mỗi câu chỉ \~0,00002 USD, còn rất xa ngân sách, nhưng từ request thứ 11 bị `429 rate limit exceeded`.

\---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> 1. Redis mất kết nối → cả 3 container cùng lúc trả lỗi ở endpoint health (vì nó ping Redis).
> 2. Sau vài lần check thất bại, orchestrator coi cả 3 là "chết" và restart cả 3 cùng lúc.
> 3. Restart không sửa được Redis → container mới lên vẫn fail check → tiếp tục bị restart (vòng lặp).
> 4. Trong thời gian đó cụm không còn container nào sống: kể cả request không cần Redis cũng bị từ chối, downtime toàn phần.
> 5. Redis có lại sau 30 giây, nhưng container đang giữa chừng restart/khởi động lạnh nên phải chờ thêm mới hồi phục — sự cố 30 giây kéo dài hơn nhiều.
>
> Khi tách riêng (đã đo): dừng Redis thì `/health` vẫn 200 (không bị restart), `/ready` 503 (bị rút khỏi load balancer); bật Redis lại thì `/ready` tự về 200, không cần restart gì.

\---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history\_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

> Tôi gọi 6 lần qua nginx với user `sv-obs-scale`: `history\_length` = `0 2 4 6 8 10`, dù log cho thấy request rơi lần lượt vào agent-1 → 3 → 2 → 1 → 3 → 2. Lý do: lịch sử nằm trong Redis dùng chung (`tokens\_in` cũng tăng dần vì prompt kèm lịch sử).
>
> Nếu lưu trong dict Python, mỗi container có lịch sử riêng trong RAM. Với round-robin như trên sẽ thấy khoảng `0 0 0 2 2 2`: con số nhảy lung tung, agent "quên" hội thoại tùy container nào xử lý, và restart container là mất sạch.

\---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS\_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> \*\*Lỗi:\*\* bản deploy trên Render có `/health` 200 nhưng `/ready` và `POST /ask` (không key) đều trả `500 Internal Server Error` (lẽ ra `/ask` phải 401).
>
> \*\*Tìm nguyên nhân:\*\* tôi chạy lại app ở máy không có `AGENT\_API\_KEY` và không có `.env` (giống container trên Render) → ra đúng `ValidationError: agent\_api\_key Field required`. `/health` không đọc `Settings` nên vẫn 200, còn `/ready`, `/ask` gọi `get\_settings()` nên lỗi 500. Service được tạo tay nên chưa có biến môi trường.
>
> \*\*Sửa:\*\* thêm `AGENT\_API\_KEY` trên Render → `/ask` trả 401 đúng, nhưng `/ready` thành `503 {"redis": false}`. Kiểm tra Environment thì `REDIS\_URL` là `redis://localhost:6379/0` chép từ `.env` — trong container trên Render, localhost là chính nó, không có Redis. Tôi tạo Render Key Value, đặt `REDIS\_URL` = Internal URL, xóa `PORT`/`DEPLOY\_API\_KEY`/`LOCAL\_FALLBACK`, redeploy → `/ready` 200 `{"redis": true}`, `test\_cp5.py` 8 passed.
>
> Bài học: cùng một image chạy đúng ở máy nhưng lỗi trên cloud chỉ vì cấu hình; `/health` 200 suốt, chỉ `/ready` mới lộ lỗi Redis.

