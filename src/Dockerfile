# syntax=docker/dockerfile:1.25@sha256:0adf442eae370b6087e08edc7c50b552d80ddf261576f4ebd6421006b2461f12
FROM debian:sid@sha256:7469781d68f44940c9494eeba6e7ab89063947f794320d61c193bf027aeb7761 AS downloader

WORKDIR /tmp

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt update && \
    apt install -y --no-install-recommends ca-certificates wget unzip && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*

# https://github.com/bitwarden/clients/releases?q=CLI
ARG BW_CLI_VERSION
ARG TARGETARCH

RUN if [ -z "$BW_CLI_VERSION" ]; then \
        echo "BW_CLI_VERSION is not set. Fetching latest version from GitHub..." && \
        BW_CLI_VERSION=$(wget -qO- https://api.github.com/repos/bitwarden/clients/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")') && \
        echo "Latest BW CLI version is $BW_CLI_VERSION"; \
    fi && \
    if [ "$TARGETARCH" = "arm64" ]; then \
        ARCH_SUFFIX="arm64-"; \
        LIB_ARCH="aarch64-linux-gnu"; \
    else \
        ARCH_SUFFIX=""; \
        LIB_ARCH="x86_64-linux-gnu"; \
    fi && \
    wget -O /tmp/bw.zip https://github.com/bitwarden/clients/releases/download/cli-v${BW_CLI_VERSION}/bw-linux-${ARCH_SUFFIX}${BW_CLI_VERSION}.zip && \
    unzip /tmp/bw.zip -d /tmp && \
    chmod +x /tmp/bw && \
    mkdir -p /tmp/data && \
    mkdir -p /tmp/lib/${LIB_ARCH} && \
    cp /usr/lib/${LIB_ARCH}/libstdc++.so.6 /tmp/lib/${LIB_ARCH}/ && \
    cp /usr/lib/${LIB_ARCH}/libgcc_s.so.1 /tmp/lib/${LIB_ARCH}/

FROM gcr.io/distroless/base-debian13:debug-nonroot@sha256:73532e54641a478ac4a0f8ebbe31e525f2c36af57a2fe10a0a3df69c40c824a6

# Bitwarden CLI listens on this port for http requests
EXPOSE 8087/tcp

ENV BW_HOST=https://vault.bitwarden.com \
    BITWARDENCLI_APPDATA_DIR=/data \
    VAULT_SYNC_INTERVAL=120

WORKDIR /

COPY --from=downloader --chown=65532:65532 --chmod=0755 /tmp/bw /usr/local/bin/bw
COPY --from=downloader --chown=65532:65532 /tmp/data $BITWARDENCLI_APPDATA_DIR
COPY --from=downloader /tmp/lib/ /usr/lib/
COPY --chown=65532:65532 --chmod=0755 entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

USER 65532:65532

HEALTHCHECK --start-period=15s --start-interval=5s --interval=10s --timeout=3s --retries=3 \
    CMD ["/busybox/sh", "-ec", "status=\"$(/busybox/wget -qO- http://127.0.0.1:8087/status)\" && echo \"$status\" | /busybox/grep -Eq '\"success\"[[:space:]]*:[[:space:]]*true' && echo \"$status\" | /busybox/grep -Eq '\"status\"[[:space:]]*:[[:space:]]*\"unlocked\"'"]
