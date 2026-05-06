# Base image with common dev tools and a non-root 'vscode' user.
FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

# ── System dependencies ────────────────────────────────────────────────────────
# libglu1-mesa / xz-utils / zip are required by the Flutter SDK toolchain.
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        git \
        unzip \
        xz-utils \
        zip \
        libglu1-mesa \
        software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y --no-install-recommends \
        python3.12 \
        python3.12-venv \
        python3.12-dev \
        python3.12-distutils \
    && rm -rf /var/lib/apt/lists/*

# Make python3.12 the default python3 and bootstrap pip for it.
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 \
    && update-alternatives --set python3 /usr/bin/python3.12 \
    && curl -sS https://bootstrap.pypa.io/get-pip.py | python3.12 \
    && ln -sf /usr/local/bin/pip3.12 /usr/local/bin/pip3

# ── Node.js LTS + Firebase CLI ─────────────────────────────────────────────────
# Node is only needed for the Firebase CLI; it is not used by the Flutter app.
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g firebase-tools

# ── Flutter SDK (stable, no Android SDK — flutter run stays on the host) ───────
ENV FLUTTER_HOME=/opt/flutter
RUN git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$FLUTTER_HOME" \
    # Pre-cache only the Linux/web artifacts; Android/iOS are not needed here.
    && "$FLUTTER_HOME/bin/flutter" precache --no-android --no-ios \
    && chown -R vscode:vscode "$FLUTTER_HOME"

ENV PATH="${FLUTTER_HOME}/bin:${PATH}"

# ── pre-commit ─────────────────────────────────────────────────────────────────
RUN pip3 install --no-cache-dir pre-commit
