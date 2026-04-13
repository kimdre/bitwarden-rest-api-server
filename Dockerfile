# syntax=docker/dockerfile:1.7
FROM debian:sid AS downloader

WORKDIR /tmp

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt update && \
    apt install -y --no-install-recommends ca-certificates wget unzip && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*

# https://github.com/bitwarden/clients/releases?q=CLI
ARG BW_CLI_VERSION

RUN if [ -z "$BW_CLI_VERSION" ]; then \
        echo "BW_CLI_VERSION is not set. Fetching latest version from GitHub..." && \
        BW_CLI_VERSION=$(wget -qO- https://api.github.com/repos/bitwarden/clients/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")') && \
        echo "Latest BW CLI version is $BW_CLI_VERSION"; \
    fi && \
    wget -O /tmp/bw.zip https://github.com/bitwarden/clients/releases/download/cli-v${BW_CLI_VERSION}/bw-linux-${BW_CLI_VERSION}.zip && \
    unzip /tmp/bw.zip -d /tmp && \
    chmod +x /tmp/bw && \
    mkdir -p /tmp/data

FROM gcr.io/distroless/base-debian13:debug-nonroot

# Bitwarden CLI listens on this port for http requests
EXPOSE 8087/tcp

ENV BW_HOST=https://vault.bitwarden.com \
    BITWARDENCLI_APPDATA_DIR=/data \
    VAULT_SYNC_INTERVAL=120

WORKDIR /

COPY --from=downloader --chown=65532:65532 /tmp/bw /usr/local/bin/bw
COPY --from=downloader --chown=65532:65532 /tmp/data $BITWARDENCLI_APPDATA_DIR
COPY --from=downloader /usr/lib/x86_64-linux-gnu/libstdc++.so.6 /usr/lib/x86_64-linux-gnu/libstdc++.so.6
COPY --from=downloader /usr/lib/x86_64-linux-gnu/libgcc_s.so.1 /usr/lib/x86_64-linux-gnu/libgcc_s.so.1
COPY --chown=65532:65532 --chmod=0755 entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

USER 65532:65532

HEALTHCHECK --start-period=15s --start-interval=5s --interval=10s --timeout=3s --retries=1 \
    CMD ["/busybox/sh", "-ec", "status=\"$(/busybox/wget -qO- http://127.0.0.1:8087/status)\" && echo \"$status\" | /busybox/grep -Eq '\"success\"[[:space:]]*:[[:space:]]*true' && echo \"$status\" | /busybox/grep -Eq '\"status\"[[:space:]]*:[[:space:]]*\"unlocked\"'"]
