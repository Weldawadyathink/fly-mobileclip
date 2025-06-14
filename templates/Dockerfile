FROM alpine:latest AS downloader
RUN apk add curl
# Download all models into a single layer; easier caching with repeated builds
RUN curl https://docs-assets.developer.apple.com/ml-research/datasets/mobileclip/mobileclip_s0.pt -o /weights/mobileclip_s0.pt --create-dirs
RUN curl https://docs-assets.developer.apple.com/ml-research/datasets/mobileclip/mobileclip_s1.pt -o /weights/mobileclip_s1.pt --create-dirs
RUN curl https://docs-assets.developer.apple.com/ml-research/datasets/mobileclip/mobileclip_s2.pt -o /weights/mobileclip_s2.pt --create-dirs
RUN curl https://docs-assets.developer.apple.com/ml-research/datasets/mobileclip/mobileclip_b.pt -o /weights/mobileclip_b.pt --create-dirs
RUN curl https://docs-assets.developer.apple.com/ml-research/datasets/mobileclip/mobileclip_blt.pt -o /weights/mobileclip_blt.pt --create-dirs


FROM python:3.13 AS builder

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1
WORKDIR /app

RUN python -m venv .venv
RUN .venv/bin/pip install torch==2.7.1 torchvision==0.22.1 --index-url https://download.pytorch.org/whl/cpu
COPY requirements.txt .
RUN .venv/bin/pip install -r requirements.txt


FROM python:3.13-slim
WORKDIR /app
COPY --from=builder /app/.venv .venv/
COPY --from=downloader /weights/${weights_file} /weights/
COPY . .
EXPOSE 8000
CMD ["/app/.venv/bin/fastapi", "run"]
