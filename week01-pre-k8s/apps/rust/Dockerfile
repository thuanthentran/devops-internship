FROM rust:1-slim-bookworm AS build
WORKDIR /app
# Bước 1: chỉ build dependency (cache lại khi Cargo.toml/Cargo.lock không đổi).
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main() {}" > src/main.rs \
    && cargo build --release --locked \
    && rm -rf src
# Bước 2: build code thật.
COPY src ./src
RUN touch src/main.rs && cargo build --release --locked

FROM debian:bookworm-slim
# curl chỉ để healthcheck trong compose.
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --no-create-home rust
USER rust
COPY --from=build /app/target/release/music-rust /usr/local/bin/music-rust
EXPOSE 8080
CMD ["music-rust"]
