ARG BUILDER=base

FROM docker.io/library/node:23.11.0-bookworm AS node

WORKDIR /app

COPY ui .

RUN --mount=type=cache,target=/app/npm/cache npm install

RUN --mount=type=cache,target=/app/npm/cache npm run build

FROM docker.io/library/rust:1.89.0-slim-bookworm AS musl-builder

ARG TARGETARCH

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache && \
    apt-get update && apt-get install -y --no-install-recommends \
    make musl-tools

RUN <<EOF
mkdir /build
if [ "$TARGETARCH" = "arm64" ]; then
  rustup target add aarch64-unknown-linux-musl;
  echo aarch64-unknown-linux-musl > /build/target
else
  rustup target add x86_64-unknown-linux-musl;
  echo x86_64-unknown-linux-musl > /build/target
fi
EOF

FROM docker.io/library/rust:1.89.0-slim-bookworm AS base-builder

ARG TARGETARCH

RUN <<EOF
mkdir /build
if [ "$TARGETARCH" = "arm64" ]; then
  echo aarch64-unknown-linux-gnu > /build/target
else
  echo x86_64-unknown-linux-gnu > /build/target
fi
echo "Building $(cat /build/target)"
EOF

FROM ${BUILDER}-builder AS builder
ARG TARGETARCH
ARG PROFILE=release

WORKDIR /app

COPY Makefile Cargo.toml Cargo.lock ./
COPY crates ./crates
COPY common ./common
COPY --from=node /app/out ./ui/out

RUN --mount=type=cache,id=cargo,target=/usr/local/cargo/registry \
    cargo fetch --locked
RUN --mount=type=cache,target=/app/target \
    --mount=type=cache,id=cargo,target=/usr/local/cargo/registry \
    cargo build --features ui  --target "$(cat /build/target)"  --profile ${PROFILE} && \
    mkdir /out && \
    mv /app/target/$(cat /build/target)/${PROFILE}/agentgateway /out

FROM debian:bookworm-slim AS runner 

ARG TARGETARCH
WORKDIR /app

# Install minimal runtime dependencies including bash for startup script
RUN apt-get update && apt-get install -y \
    ca-certificates \
    bash \
    coreutils \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -r agentgateway \
    && useradd -r -g agentgateway agentgateway

COPY --from=builder /out/agentgateway /app/agentgateway

# Add Cloud Run configuration and startup script
COPY deployment/simple-cloudrun-config.yaml /app/cloudrun-config.yaml
COPY deployment/docker-entrypoint.sh /app/docker-entrypoint.sh

# Make startup script executable and set ownership
RUN chmod +x /app/docker-entrypoint.sh && \
    chown -R agentgateway:agentgateway /app

# Switch to non-root user
USER agentgateway

# Environment variables for Cloud Run
ENV CONFIG_FILE_PATH=/app/cloudrun-config.yaml
ENV PORT=8080

LABEL org.opencontainers.image.source=https://github.com/agentgateway/agentgateway
LABEL org.opencontainers.image.description="Agentgateway is an open source project that is built on AI-native protocols to connect, secure, and observe agent-to-agent and agent-to-tool communication across any agent framework and environment."

# Use startup script as entrypoint for Cloud Run compatibility
ENTRYPOINT ["/app/docker-entrypoint.sh"]
