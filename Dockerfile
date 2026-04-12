FROM debian:sid

# Bitwarden CLI listens on this port for http requests
EXPOSE 8087/tcp

ENV BW_HOST=https://vault.bitwarden.com

# https://github.com/bitwarden/clients/releases?q=CLI
ARG BW_CLI_VERSION

RUN apt update && \
    apt install -y wget unzip

COPY entrypoint.sh /

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

HEALTHCHECK --start-period=20s --retries=3 --interval=120s --timeout=10s \
    CMD ["wget", "-q", "http://localhost:8087/sync?force=true", "--post-data=''"]