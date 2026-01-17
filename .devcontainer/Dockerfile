FROM ghcr.io/astral-sh/uv:debian

# Install Node.js and npm
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | sh - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*