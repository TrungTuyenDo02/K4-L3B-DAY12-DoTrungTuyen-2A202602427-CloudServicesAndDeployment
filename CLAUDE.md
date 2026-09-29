# CLAUDE.md — K4 L3B Day 12: Cloud Services & Deployment

File này hướng dẫn Claude Code làm bài lab trong repo này. Đọc hết trước khi sửa bất cứ thứ gì.

## 0. Bối cảnh

- Học viên: **Đỗ Trung Tuyến**, MSSV **2A202602427**, GitHub `TrungTuyenDo02`.
- Tên repo đúng (theo README/SUBMISSION): `K4-L3B-DAY12-DoTrungTuyen-2A202602427-CloudServicesAndDeployment`
  (chú ý chữ **s** trong `Services`). Học viên tự đổi tên repo trên GitHub, **Claude không đổi**, nhưng mọi chỗ
  ghi tên/URL repo (DEPLOYMENT.md, badge README) phải dùng tên đúng ở trên.
- Môi trường **đã setup xong** (venv, requirements, `.env`, Redis). **Không** cài lại, không tạo venv, không sửa `.env`.
- Yêu cầu chính thức: `README.md`, `LAB_GUIDE.md`, `CHECKPOINTS.md`, `RUBRIC.md`, `RULES.md`, `SUBMISSION.md`.
  Docstring/TODO trong `app/*.py`, `Dockerfile`, `docker-compose.yml` là đặc tả chi tiết. Test trong `tests/` là
  tiêu chí chấm. Khi mâu thuẫn, test và tài liệu trên được ưu tiên.

## 1. Quy tắc làm việc (bắt buộc)

1. **Làm từng checkpoint một, theo thứ tự CP1 → CP6. Hết mỗi CP thì DỪNG LẠI.** Báo cáo:
   - các file đã sửa và mỗi thay đổi làm gì (ngắn gọn, đủ để học viên giải thích lại cho Lab Coach),
   - lệnh test học viên cần chạy, ví dụ `pytest tests/test_cp1.py -v`,
   - gợi ý commit message, ví dụ `git commit -m "CP1: 12-factor config, health, JSON logging"`.

   Sau đó **chờ học viên xác nhận** mới sang CP tiếp theo. Không gộp nhiều CP.
2. Claude được chạy pytest của CP hiện tại **một lần** để tự kiểm tra và sửa nếu đỏ; học viên vẫn tự chạy lại.
   Không chạy test của CP sau.
3. **Không commit, không push, không đổi tên nhánh/repo.** Lịch sử commit phải là của học viên.
4. **Không sửa**: `tests/`, `grade.py`, `utils/mock_llm.py`, `nginx/nginx.conf`, `.env`, và các phần ghi
   "CHO SẴN" trong code. Chỉ điền vào các TODO.
5. **Secret:** không bao giờ in, đọc to, hay ghi giá trị `AGENT_API_KEY`/`DEPLOY_API_KEY`/token platform vào file
   hoặc output. Khi curl cần key: `set -a; . ./.env; set +a` rồi dùng biến `$AGENT_API_KEY`. Không hardcode các
   chuỗi như `sk-`, `password`, `AGENT_API_KEY=...` trong code hay Dockerfile.
6. Code ngắn, dễ đọc, bám đúng TODO. Không thêm tính năng, không format lại file không liên quan.
   Comment tiếng Việt ngắn gọn.
7. **Không bịa** output test, URL deploy, dung lượng image hay log. Chỉ ghi những gì đã thật sự chạy.
8. `exercises.md`: **Claude không viết câu trả lời vào file này.** Xem mục 4.

## 2. Các checkpoint

### CP1 — 12-Factor Config, Health & Logging (`tests/test_cp1.py`)
- `app/config.py`: 6 trường `port:int=8000`, `agent_api_key:str` (**không mặc định**),
  `redis_url:str="redis://localhost:6379/0"`, `rate_limit_per_minute:int=10`, `monthly_budget_usd:float=10.0`,
  `log_level:str="INFO"`.
- `app/logging_utils.py` `log_event`: dict `event`, `level` (viết thường), `timestamp` (`utc_now_iso()`) + `**fields`;
  `json.dumps(..., ensure_ascii=False)` trên **một dòng**, `print` ra stdout, trả về chuỗi đó.
- `app/main.py` `/health`: **hàm không nhận tham số/Depends nào**. `lifecycle.shutting_down` → 503
  `{"status":"shutting_down"}`; ngược lại `{"status":"ok","service":SERVICE_NAME,"version":SERVICE_VERSION}`.
  Không chạm Redis.
- Kiểm tra tay (cho học viên): `uvicorn app.main:app --reload --port 8000` → `curl -i localhost:8000/health`.
  Lưu ý: lúc này `/ask`, `/ready` vẫn NotImplemented — bình thường.

### CP2 — Docker (`tests/test_cp2.py`)
- **Trước khi sửa**, copy Dockerfile gốc thành `Dockerfile.single` (giữ nguyên) để học viên đo dung lượng image
  1 stage cho câu 3 exercises.
- `Dockerfile`: multi-stage `FROM python:3.11-slim AS builder` → `pip install --no-cache-dir --prefix=/install -r requirements.txt`
  → `FROM python:3.11-slim AS runtime` + `COPY --from=builder /install /usr/local`; `COPY requirements.txt` + cài
  **trước** khi copy code; chỉ copy `app/` và `utils/` (không `COPY . .`); tạo user `appuser` uid 10001 + `USER appuser`;
  `ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1`; `HEALTHCHECK` gọi `/health` ở cổng `${PORT:-8000}`
  (dạng shell để biến được thay); `CMD ["sh","-c","uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]`.
- `.dockerignore`: tối thiểu `.env`, `.env.*`, `__pycache__`, `*.pyc`, `.git`, `.venv`, `venv`, `.pytest_cache`,
  `tests`, `screenshots`, `.github`, `.claude-notes`, `*.md`. **Không** ignore `app`, `utils`, `requirements.txt`.
- `docker-compose.yml`: thêm service `agent`: `build: .`, `ports: ["8000:8000"]`,
  `environment:` `AGENT_API_KEY: ${AGENT_API_KEY}` và `REDIS_URL: redis://redis:6379/0` (thêm
  RATE_LIMIT_PER_MINUTE, MONTHLY_BUDGET_USD, LOG_LEVEL dạng `${VAR:-mặc_định}`), `depends_on: redis`
  (`condition: service_healthy`), `healthcheck` gọi `/health`. Không đặt `container_name` (để `--scale` chạy được).
  Giữ `8000:8000` cho 1 instance; báo học viên rằng `--scale agent=3` cần dải cổng (`"8000-8002:8000"`) hoặc
  nginx — chỉ gợi ý, không tự đổi nếu chưa được yêu cầu.
- Lệnh cho học viên: `docker build -t day12-agent:prod .`, `docker images day12-agent:prod`,
  `docker compose up -d --build`, `curl localhost:8000/health`.

### CP3 — API Security (`tests/test_cp3.py`)
- `app/auth.py`: thiếu key hoặc `not secrets.compare_digest(x_api_key, expected)` → 401 `"invalid or missing API key"`;
  trả về `x_user_id or ANONYMOUS_USER`.
- `app/rate_limiter.py`: `hit_count` = `zremrangebyscore(key, 0, now-60)` rồi `zcard`; `check` **kiểm tra trước**
  (`>= limit` → 429 + header `Retry-After`), **ghi nhận sau** `zadd({f"{now}:{uuid4().hex}": now})` + `expire`.
  Luôn dùng tham số `now` được truyền vào.
- `app/cost_guard.py`: `spent` trả `0.0` khi chưa có key, còn lại ép `float`; `check` → 402 khi
  `spent + estimated_cost > budget`; `record` = `incrbyfloat` + `expire(KEY_TTL_SECONDS)` + trả `float`.
- `/ask` trong `main.py`: đúng 8 bước trong docstring (limiter → guard → get_history → ask_llm → append ×2 →
  record → log_event → response đủ các trường `answer, user_id, history_length, cost_usd, tokens`).

### CP4 — Scaling & Reliability (`tests/test_cp4.py`)
- `app/store.py`: `ping` try/except → bool; `append` = `rpush` + `ltrim(key, -HISTORY_MAX_MESSAGES, -1)` + `expire`;
  `get_history` = `lrange` + `json.loads`, rỗng → `[]`. **Không có dict/list toàn cục** giữ state trong `main.py`/`store.py`.
- `app/lifecycle.py`: `request_shutdown` bật cờ rồi gọi lại handler cũ nếu `callable`; `install` lưu
  `signal.getsignal(sig)` rồi `signal.signal(sig, self.request_shutdown)` (truyền tham chiếu, không gọi hàm) cho
  SIGTERM và SIGINT.
- `/ready`: đang tắt → 503 `{"status":"shutting_down"}`; `not store.ping()` → 503
  `{"status":"not ready","redis":False}`; ngược lại `{"status":"ready","redis":True}`.
- Kiểm tra không còn `NotImplementedError` trong `app/` (`grep -rn NotImplementedError app/`).
- Gợi ý học viên tự chạy thử scale thủ công theo LAB_GUIDE Block 4.

### CP5 — Cloud Deployment (`tests/test_cp5.py`)
- **Đầu CP5, Chon Render de deloy (hoặc local fallback nếu không deploy được).
  Không tự chọn.
- Railway: đã có `railway.toml`. Render: đã có `render.yaml`. Chỉ sửa khi thật cần.
  Đưa học viên chuỗi lệnh theo LAB_GUIDE Block 5 — **học viên tự chạy** login/deploy/set secret trên dashboard.
  Claude không làm thay và không nhận giá trị key.
- Khi học viên gửi URL thật, điền `DEPLOYMENT.md`:
  - Họ tên `Đỗ Trung Tuyến`, mã học viên `2A202602427`, link repo dùng **tên đúng** (`...CloudServicesAndDeployment`).
  - Public URL (https), platform, ngày deploy, nguồn REDIS_URL.
  - **Không được còn placeholder `(điền ...)` nào** — kể cả mục "Nếu Dùng Phương Án Dự Phòng": nếu không dùng
    fallback thì xóa dòng `(điền lý do ...)` / cả khối code đó, nếu không test sẽ rớt.
  - "Kết Quả Chạy Thật": chỉ dán output học viên đã thật sự chạy (nhờ học viên dán vào hoặc cùng chạy). Không bao
    giờ ghi giá trị key — chỉ ghi tên biến.
- Nhắc học viên: đặt `screenshots/dashboard.png` và `screenshots/health.png`; set `DEPLOY_API_KEY` trong `.env`
  nếu muốn chạy test có xác thực.
- Nếu dùng fallback: `LOCAL_FALLBACK=true` trong `.env` (học viên tự set), `docker compose up -d`, ít nhất
  1 ảnh chụp màn hình, và ghi lý do vào DEPLOYMENT.md.

### CP6 — BONUS CI/CD (`tests/test_bonus_cicd.py`) — chỉ làm sau khi CP5 xong
- Tạo `.github/workflows/ci.yml`:
  - `on: push` + `pull_request` trên nhánh `main`.
  - Job `test`: `actions/checkout@v4`, `actions/setup-python@v5` (3.11), `pip install -r requirements.txt`,
    `pytest tests/ -v --ignore=tests/test_cp5.py --ignore=tests/test_bonus_cicd.py`,
    `env: AGENT_API_KEY: ci-dummy`, `REDIS_URL: "fake://"`.
  - Job `build`: checkout + `docker build -t day12-agent:ci .`.
  - Job `deploy`: `needs: [test, build]`, `if: github.ref == 'refs/heads/main' && github.event_name == 'push'`.
    Deploy theo platform đã chọn ở CP5:
    Railway → cài CLI rồi `railway up --service <tên> --detach` với `RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN }}`;
    Render → `curl -fsS -X POST "${{ secrets.RENDER_DEPLOY_HOOK }}"`.
    Sau đó smoke test: `sleep 45` + `curl -fsS "${{ vars.PUBLIC_URL }}/health"`.
  - Mọi `uses:` phải ghim phiên bản (`@v4`, `@v5`…), không dùng `@main`/`@master`. Không có token trong YAML.
- Thêm badge ở đầu `README.md`:
  `![CI](https://github.com/TrungTuyenDo02/K4-L3B-DAY12-DoTrungTuyen-2A202602427-CloudServicesAndDeployment/actions/workflows/ci.yml/badge.svg)`
  (repo phải đã đổi tên + public, nếu không badge trả 404).
- Báo học viên việc cần làm trên GitHub: tạo secret (`RAILWAY_TOKEN` hoặc `RENDER_DEPLOY_HOOK`) và variable
  `PUBLIC_URL` ở Settings → Secrets and variables → Actions; push rồi xem tab Actions.

## 3. Sau CP cuối
Nhắc học viên chạy: `python grade.py`, `git ls-files | grep -E '(^|/)\.env$'` (phải rỗng),
`grep -rn NotImplementedError app/`, và rà danh sách kiểm tra trong README.

## 4. Ghi chú quan sát cho exercises.md (KHÔNG phải câu trả lời)

Học viên tự viết `exercises.md` bằng lời của mình. Claude chỉ ghi **quan sát thật** vào
`.claude-notes/observations.md` để học viên tham khảo (lần đầu tạo thì thêm `.claude-notes/` vào `.gitignore` và
`.dockerignore` để file không lọt vào repo/image).

Sau mỗi CP, ghi thêm vào file đó, nhóm theo số câu, **chỉ dữ liệu đã chạy/thấy thật**:
- Câu 1 (CP1): lỗi thật khi tạo `Settings` thiếu `AGENT_API_KEY` (thông báo ValidationError).
- Câu 2 (CP1/CP3): một dòng log JSON thật từ `/ask` (không chứa giá trị key).
- Câu 3 (CP2): dung lượng thật từ `docker images` của `Dockerfile.single` và bản multi-stage (nếu học viên tự
  build và dán output thì ghi đúng output đó).
- Câu 4 (CP2): layer nào `CACHED` / chạy lại sau khi sửa một ký tự trong `app/main.py` (từ log build thật).
- Câu 5 (CP2): output `docker compose exec agent id` (cho thấy uid không phải root).
- Câu 6–7 (CP3): chuỗi status code thật từ vòng curl 15 lần; trường hợp 402 trong test.
- Câu 8–9 (CP4): hành vi thật của `/ready` khi dừng Redis (`docker compose stop redis`) so với `/health`; chuỗi
  `history_length` khi scale 3 instance.
- Câu 10 (CP5): lỗi/log thật gặp khi deploy và cách đã sửa.

Định dạng: dữ liệu + nhận xét ngắn (1–2 câu về điều dữ liệu cho thấy). **Không viết thành câu trả lời hoàn chỉnh**,
không tự điền số liệu còn thiếu; phần nào chưa chạy thì ghi `(chưa chạy)`.