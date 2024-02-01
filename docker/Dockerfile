# syntax=docker/dockerfile:1.4
ARG ALPINE_VERSION=3.19
ARG RUST_VERSION=1.75

################################################################################

FROM --platform=$BUILDPLATFORM rust:$RUST_VERSION-alpine$ALPINE_VERSION AS builder
ARG BUILDPLATFORM
ARG TARGETPLATFORM

RUN \
    --mount=type=cache,id=$BUILDPLATFORM-alpine,target=/var/cache/apk,sharing=locked \
    set -eux; \
    apk update; \
    if [ "$BUILDPLATFORM" == "$TARGETPLATFORM" ]; then \
        apk add gcc musl-dev; \
    else \
        case "${TARGETPLATFORM}" in \
            linux/arm64) arch='aarch64';; \
            *) echo "unsupported architecture"; exit 1 ;; \
        esac; \
        apk add gcc-${arch}-none-elf; \
        host_arch=$(cat /etc/apk/arch); \
        echo "${arch}" > /etc/apk/arch; \
        apk add --no-cache --allow-untrusted musl-dev; \
        echo "${host_arch}" > /etc/apk/arch; \
    fi;

WORKDIR /opt/aode-relay

ADD Cargo.lock Cargo.toml /opt/aode-relay/
RUN cargo fetch;

ADD . /opt/aode-relay

RUN set -eux; \
    export RUSTFLAGS="-C target-cpu=generic -C target-feature=-crt-static -C link-self-contained=no"; \
    if [ "$BUILDPLATFORM" != "$TARGETPLATFORM" ]; then \
        case "${TARGETPLATFORM}" in \
            linux/arm64) arch='aarch64';; \
            *) echo "unsupported architecture"; exit 1 ;; \
        esac; \
        rustup target add "${arch}-unknown-linux-musl"; \
        ln -s "target/${arch}-unknown-linux-musl/release/relay" "aode-relay"; \
        export CC="${arch}-none-elf-gcc"; \
        export RUSTFLAGS="$RUSTFLAGS -C linker=${arch}-none-elf-gcc"; \
        export CARGO_BUILD_TARGET="${arch}-unknown-linux-musl"; \
    else \
        case "${TARGETPLATFORM}" in \
            linux/amd64) arch='x86_64';; \
            linux/arm64) arch='aarch64';; \
            *) echo "unsupported architecture"; exit 1 ;; \
        esac; \
        ln -s "target/${arch}-unknown-linux-musl/release/relay" "aode-relay"; \
    fi; \
    cargo build --frozen --release;

################################################################################

FROM alpine:$ALPINE_VERSION
ARG TARGETPLATFORM

RUN \
    --mount=type=cache,id=$TARGETPLATFORM-alpine,target=/var/cache/apk,sharing=locked \
    set -eux; \
    apk add -U ca-certificates curl tini;

COPY --link --from=builder /opt/aode-relay/aode-relay /usr/local/bin/aode-relay

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
