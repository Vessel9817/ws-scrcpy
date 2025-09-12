FROM ubuntu:jammy-20230624@sha256:b060fffe8e1561c9c3e6dea6db487b900100fc26830b9ea2ec966c151ab4c020 AS nvm

RUN \
    apt-get update -qq \
    && apt-get install -yqq --no-install-recommends \
        binutils \
        ca-certificates \
        coreutils \
        curl \
        findutils \
        g++ \
        gcc \
        grep \
        libncurses5-dev \
        libncursesw5-dev \
        linux-headers-6.8.0-79-generic \
        make \
        openssl \
        python3 \
        util-linux \
    && apt-get clean -qq

# Installing NVM
# https://github.com/nvm-sh/nvm?tab=readme-ov-file#installing-in-docker
ENV NVM_DIR="/root/.nvm"
ARG NVM_VERSION="v0.40.3"
ARG NVM_HASH="sha256:2d8359a64a3cb07c02389ad88ceecd43f2fa469c06104f92f98df5b6f315275f"
ADD --checksum="${NVM_HASH}" --chmod="+x" [ \
    "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh", \
    "/tmp/" \
]
RUN \
    '/tmp/install.sh' \
    && rm '/tmp/install.sh'

# Installing Node.js and NPM
# https://nodejs.org/en/download/releases
SHELL [ "bash", "-c" ]
ENV NODE_VERSION="16.20.2"
RUN \
    source "${NVM_DIR}/nvm.sh" \
    && nvm install "${NODE_VERSION}" \
    && nvm use "${NODE_VERSION}"

ENTRYPOINT ["bash", "-c", "source $NVM_DIR/nvm.sh && exec \"$@\"", "--"]
CMD [ "tail", "-f", "/dev/null" ]
