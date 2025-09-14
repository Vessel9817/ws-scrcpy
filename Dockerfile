ARG BASE_IMAGE=ubuntu:jammy-20230624@sha256:b060fffe8e1561c9c3e6dea6db487b900100fc26830b9ea2ec966c151ab4c020

FROM ${BASE_IMAGE} AS nvm

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
ARG NVM_HASH=sha256:2d8359a64a3cb07c02389ad88ceecd43f2fa469c06104f92f98df5b6f315275f
ADD --checksum="${NVM_HASH}" --chmod="+x" [ \
    "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh", \
    "/tmp/" \
]
RUN \
    '/tmp/install.sh' \
    && rm '/tmp/install.sh'

# Installing Node.js and NPM
# Projected EOL of v24: Oct 2028
# https://nodejs.org/en/download/releases
SHELL [ "bash", "-c" ]
ENV NODE_VERSION="24.8.0"
RUN \
    source "${NVM_DIR}/nvm.sh" \
    && nvm install "${NODE_VERSION}" \
    && nvm use "${NODE_VERSION}" \
    && apt-get remove -yqq \
        curl \
        python3 \
    && apt-get clean -qq

ENTRYPOINT [ "bash", "-c", "source \"${NVM_DIR}/nvm.sh\" && exec \"$@\"", "--" ]
CMD [ "tail", "-f", "/dev/null" ]

FROM nvm AS ws_scrcpy

# node-gyp depends on gcc and make
# Everything else is an optional/required dependency of Python
RUN \
    # deb-src is necessary for apt-get build-dep
    sed -i 's/^# deb-src /deb-src /' /etc/apt/sources.list \
    && apt-get update -qq \
    # Shuts up interactive dependency installations
    && DEBIAN_FRONTEND=noninteractive apt-get install -yqq \
        tzdata \
    && apt-get build-dep -qq --no-install-recommends \
        python3 \
    && apt-get install -yqq --no-install-recommends \
        build-essential \
        gcc \
        gdb \
        # https://github.com/python/devguide/issues/1654
        inetutils-inetd \
        lcov \
        libbz2-dev \
        libffi-dev \
        libgdbm-compat-dev \
        libgdbm-dev \
        liblzma-dev \
        libncurses5-dev \
        libreadline6-dev \
        libsqlite3-dev \
        libssl-dev \
        libzstd-dev \
        lzma \
        lzma-dev \
        make \
        pkg-config \
        tk-dev \
        uuid-dev \
        zlib1g-dev \
    && apt-get clean -qq

# Downloading Python
WORKDIR /usr/local/bin/
# https://devguide.python.org/versions/#full-chart
ARG PYTHON_VERSION=3.13.7
ARG PYTHON_HASH=sha256:6c9d80839cfa20024f34d9a6dd31ae2a9cd97ff5e980e969209746037a5153b2
ADD --checksum=${PYTHON_HASH} \
    "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz" \
    "./python.tgz"
RUN \
    tar -xzf './python.tgz' \
    && rm './python.tgz' \
    && mv "./Python-${PYTHON_VERSION}" "./python3"

# Installing Python
WORKDIR /usr/local/bin/python3/
RUN \
    './configure' \
    && make \
    && make test \
    && make install

ENV PYTHON="/usr/local/bin/python3/python"

# Installing ws-scrcpy
WORKDIR /usr/ws-scrcpy/
COPY [ "./package.json", "./package-lock.json*", "./npm-shrinkwrap.json*", "./" ]
RUN \
    source "${NVM_DIR}/nvm.sh" \
    && npm i

COPY [ "./", "./" ]
RUN \
    source "${NVM_DIR}/nvm.sh" \
    && npm run dist

WORKDIR /usr/ws-scrcpy/dist/
RUN \
    source "${NVM_DIR}/nvm.sh" \
    && npm i

ARG NODE_GYP_VERSION="^11.4.2"
RUN \
    source "${NVM_DIR}/nvm.sh" \
    npm i -g "node-gyp@${NODE_GYP_VERSION}"

CMD [ "npm", "start" ]
EXPOSE 8000
