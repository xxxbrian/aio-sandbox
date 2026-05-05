FROM debian:bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=agent
ARG USER_UID=1000
ARG USER_GID=1000

# Install system dependencies, common tools, and headless browser stack.
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    build-essential \
    curl \
    wget \
    git \
    ripgrep \
    fd-find \
    jq \
    zip \
    unzip \
    p7zip-full \
    xz-utils \
    zstd \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libffi-dev \
    liblzma-dev \
    tk-dev \
    gnupg \
    dirmngr \
    sqlite3 \
    ffmpeg \
    imagemagick \
    poppler-utils \
    python3 \
    python3-venv \
    python3-pip \
    pipx \
    chromium \
    chromium-sandbox \
    fonts-liberation \
    fonts-noto-cjk \
    fonts-noto-color-emoji \
    libnss3 \
    libatk-bridge2.0-0 \
    libgtk-3-0 \
    libxss1 \
    libasound2 \
    libdrm2 \
    libgbm1 \
    libxshmfence1 \
    procps \
    tini \
    && rm -rf /var/lib/apt/lists/*

# fd-find installs as `fdfind` on Debian; create the common `fd` alias.
# Install uv via pipx into /usr/local/bin for all users.
RUN ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin pipx install uv

# Create unprivileged user.
RUN groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME}

ENV MISE_DATA_DIR=/opt/mise-data
ENV PATH=/usr/local/bin:${MISE_DATA_DIR}/shims:${PATH}

# Install mise binary.
RUN curl -fsSL https://mise.run | sh \
    && mv /root/.local/bin/mise /usr/local/bin/mise \
    && mkdir -p ${MISE_DATA_DIR} \
    && chown -R ${USERNAME}:${USERNAME} ${MISE_DATA_DIR}

WORKDIR /workspace

# Install runtime toolchains defined in mise.toml.
USER ${USERNAME}
COPY --chown=${USERNAME}:${USERNAME} mise.toml /workspace/mise.toml
RUN MISE_JOBS=1 mise trust /workspace/mise.toml \
    && MISE_JOBS=1 mise settings set python.compile false \
    && MISE_JOBS=1 mise install \
    && MISE_JOBS=1 mise use -g node@24 python@3.13 go@latest bun@latest

# Make Chromium path explicit for automation tools.
ENV CHROME_BIN=/usr/bin/chromium
ENV CHROMIUM_PATH=/usr/bin/chromium

# Ensure non-root runtime and persistent shell activation.
USER root
RUN printf '%s\n' 'export PATH="/opt/mise-data/shims:$PATH"' > /etc/profile.d/mise-path.sh \
    && chmod 0644 /etc/profile.d/mise-path.sh
USER ${USERNAME}
RUN echo 'eval "$(mise activate bash)"' >> /home/${USERNAME}/.bashrc

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["bash"]
