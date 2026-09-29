# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization (bản production-ready)
#
# Bản 1 stage ban đầu được giữ ở Dockerfile.single để so sánh dung lượng.
#
# Kiểm tra:  pytest tests/test_cp2.py -v
# Build thử: docker build -t day12-agent:prod .
#            docker images day12-agent:prod     # xem dung lượng
# ═══════════════════════════════════════════════════════════════════

# ── Stage 1: builder — cài dependency vào /install, stage này bị bỏ đi ──
FROM python:3.11-slim AS builder

WORKDIR /build

# Copy requirements trước → sửa code không làm mất cache của layer pip install
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Stage 2: runtime — chỉ mang kết quả cài đặt + code sang ──
FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

COPY --from=builder /install /usr/local

WORKDIR /app

# Chỉ copy đúng thứ app cần, không COPY . .
COPY app ./app
COPY utils ./utils

# User thường, không chạy bằng root
RUN useradd --create-home --uid 10001 appuser
USER appuser

EXPOSE 8000

# Dạng shell để ${PORT:-8000} được thay bằng cổng thật
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:${PORT:-8000}/health', timeout=3)" || exit 1

# Cloud tự gán PORT; chạy local thì mặc định 8000
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
