# =============================================================================
# UNIT3D Upload Checker - Dockerfile
# =============================================================================
# Builds a production image from the local repository checkout. The compose files
# set the build context to the repo root and this Dockerfile path to
# docker/Dockerfile.
# =============================================================================

ARG PYTHON_VERSION=3.11

# =============================================================================
# STAGE 1: Builder
# =============================================================================
# Installs Python packages into a separate directory so the runtime image does
# not need pip cache or build-only filesystem state.
# =============================================================================
FROM python:${PYTHON_VERSION}-slim AS builder

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /tmp/build

COPY requirements.txt .

RUN pip install --no-cache-dir --target=/tmp/deps -r requirements.txt

# =============================================================================
# STAGE 2: Runtime
# =============================================================================
FROM python:${PYTHON_VERSION}-slim AS runtime

LABEL maintainer="UNIT3D Upload Checker"
LABEL description="Automated tracker upload checker for UNIT3D-based private trackers"
LABEL version="2.0"
LABEL org.opencontainers.image.source="https://github.com/stuckKY/UNIT3D-Upload-Checker"

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONPATH=/usr/local/lib/python-packages \
    DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    mediainfo \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

WORKDIR /app

COPY --from=builder /tmp/deps /usr/local/lib/python-packages
COPY . /app
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN mkdir -p /app/data /app/outputs /app/scripts /data \
    && cp /app/docker/scripts/setup.sh /app/scripts/setup.sh \
    && chmod +x /app/check.py /app/scripts/setup.sh /usr/local/bin/entrypoint.sh

VOLUME ["/data", "/app/data", "/app/outputs"]

WORKDIR /app

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD python3 -c "import requests; import mediainfo; from PTN.parse import PTN" || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]

# =============================================================================
# Usage
# =============================================================================
# From the repository root:
#   docker build -f docker/Dockerfile -t unit3d-checker:latest .
#   docker compose -f docker/docker-compose.yml up -d --build
#
# From the docker/ directory:
#   docker compose up -d --build
# =============================================================================
