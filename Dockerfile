FROM debian:sid@sha256:bcd97037d04fa619b2aad55c3bf32b0f4f590dc6c5a77d86b1f9c42b306e2cfc

# Bitwarden CLI listens on this port for http requests
EXPOSE 8087/tcp

ENV BW_HOST=https://vault.bitwarden.com \
    BITWARDENCLI_APPDATA_DIR=/data

WORKDIR /

ARG UID=1000
ARG GID=$UID

RUN apt update && \
    apt install -y wget unzip && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* && \
    groupadd --gid $GID bitwardencli && \
    useradd --uid $UID --gid $GID -m bitwardencli && \
    mkdir -p ${BITWARDENCLI_APPDATA_DIR} && \
    chown -R bitwardencli:bitwardencli ${BITWARDENCLI_APPDATA_DIR}

COPY entrypoint.sh /

# https://github.com/bitwarden/clients/releases?q=CLI
ARG BW_CLI_VERSION

RUN if [ -z "$BW_CLI_VERSION" ]; then \
        echo "BW_CLI_VERSION is not set. Fetching latest version from GitHub..." && \
        BW_CLI_VERSION=$(wget -qO- https://api.github.com/repos/bitwarden/clients/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")') && \
        echo "Latest BW CLI version is $BW_CLI_VERSION"; \
    fi && \
    wget https://github.com/bitwarden/clients/releases/download/cli-v${BW_CLI_VERSION}/bw-linux-${BW_CLI_VERSION}.zip && \
    unzip bw-linux-${BW_CLI_VERSION}.zip && \
    chmod +x bw entrypoint.sh && \
    mv bw /usr/local/bin/bw && \
    rm -rfv *.zip

CMD ["/entrypoint.sh"]

USER bitwardencli

HEALTHCHECK --start-period=15s --start-interval=5s --interval=10s --timeout=3s --retries=1 \
    CMD ["sh", "-ec", "status=\"$(wget -qO- http://localhost:8087/status)\" && echo \"$status\" | grep -Eq '\"success\"[[:space:]]*:[[:space:]]*true' && echo \"$status\" | grep -Eq '\"status\"[[:space:]]*:[[:space:]]*\"unlocked\"'"]
