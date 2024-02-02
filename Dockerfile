# syntax=docker/dockerfile:1.4
ARG ALPINE_VERSION=3.19
ARG RUST_VERSION=1.75

################################################################################

FROM rust:$RUST_VERSION-alpine$ALPINE_VERSION AS builder
ARG BUILDPLATFORM
ARG RUSTFLAGS="-C target-cpu=generic"

RUN \
    --mount=type=cache,id=$BUILDPLATFORM:/var/cache/apk,target=/var/cache/apk,sharing=locked \
    set -eux; \
    apk add -U build-base;

WORKDIR /opt/aode-relay

COPY --link Cargo.lock Cargo.toml .cargo /opt/aode-relay/
RUN \
    --mount=type=cache,id=$BUILDPLATFORM:/root/.cargo,target=/root/.cargo \
    cargo fetch;

COPY . /opt/aode-relay

RUN \
    --mount=type=cache,id=$BUILDPLATFORM:/root/.cargo,target=/root/.cargo \
    set -eux; \
    cargo build --frozen --release;

################################################################################

FROM alpine:$ALPINE_VERSION
ARG TARGETPLATFORM

RUN \
    --mount=type=cache,id=$TARGETPLATFORM:/var/cache/apk,target=/var/cache/apk,sharing=locked \
    set -eux; \
    apk add -U ca-certificates curl tini;

COPY --link --from=builder /opt/aode-relay/target/release/relay /usr/local/bin/aode-relay

# Smoke test
RUN /usr/local/bin/aode-relay --help

# Some base env configuration
ENV ADDR 0.0.0.0
ENV PORT 8080
ENV DEBUG false
ENV VALIDATE_SIGNATURES true
ENV HTTPS false
ENV PRETTY_LOG false
ENV PUBLISH_BLOCKS true
ENV SLED_PATH "/var/lib/aode-relay/sled/db-0.34"
ENV RUST_LOG warn

VOLUME "/var/lib/aode-relay"

ENTRYPOINT ["/sbin/tini", "--"]

CMD ["/usr/local/bin/aode-relay"]

EXPOSE 8080

HEALTHCHECK CMD curl -sSf "localhost:$PORT/healthz" > /dev/null || exit 1
