# syntax=docker/dockerfile:1

# =========================================================================
# Stage 1: fetcher — baixa e verifica o binário oficial do Bitcoin Core.
# Nada aqui é compilado; o release já vem pré-compilado e estaticamente
# linkado, então não há necessidade de toolchain de build.
# =========================================================================
FROM debian:bookworm-slim AS fetcher

ARG BITCOIN_VERSION=28.1
ARG BITCOIN_SHA256=07f77afd326639145b9ba9562912b2ad2ccec47b8a305bd075b4f4cb127b7ed7

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates wget && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /bitcoin_download

RUN wget -q "https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz" && \
    echo "${BITCOIN_SHA256}  bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz" | sha256sum -c - && \
    tar xf "bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz" && \
    mv "bitcoin-${BITCOIN_VERSION}/bin/bitcoind" "bitcoin-${BITCOIN_VERSION}/bin/bitcoin-cli" . && \
    rm -rf "bitcoin-${BITCOIN_VERSION}" "bitcoin-${BITCOIN_VERSION}-x86_64-linux-gnu.tar.gz"

# =========================================================================
# Stage 2: runtime — imagem final, só com o necessário para rodar o node.
# =========================================================================
FROM debian:bookworm-slim AS runtime

LABEL maintainer="Paulo Henrique (@paulohsilvavieira)"

# jq: parse de listwallets nos scripts. gettext-base: envsubst do bitcoin.conf.
RUN apt-get update && \
    apt-get install -y --no-install-recommends jq gettext-base && \
    rm -rf /var/lib/apt/lists/*

COPY --from=fetcher /bitcoin_download/bitcoind /bitcoin_download/bitcoin-cli /usr/local/bin/

RUN useradd --system --create-home --shell /usr/sbin/nologin bitcoin && \
    mkdir -p /bitcoin && \
    chown -R bitcoin:bitcoin /bitcoin

COPY bitcoin.conf.template /bitcoin/bitcoin.conf.template
COPY scripts/createwallet.sh scripts/automining.sh /scripts/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /scripts/createwallet.sh /scripts/automining.sh /entrypoint.sh && \
    chown -R bitcoin:bitcoin /scripts /bitcoin/bitcoin.conf.template

USER bitcoin

ENV RPC_USER=admin \
    RPC_PASSWORD=admin \
    WALLET_NAME=bitcoin-wallet-regtest \
    MINING_INTERVAL=10 \
    TX_MIN_AMOUNT=0.0001 \
    TX_MAX_AMOUNT=0.01 \
    TX_MIN_FEE_RATE=1 \
    TX_MAX_FEE_RATE=20 \
    TX_MIN_BALANCE=0.01

# 18443 = RPC regtest, 18444 = P2P regtest, 29000 = ZMQ
EXPOSE 18443 18444 29000

HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=6 \
    CMD bitcoin-cli -regtest -conf=/bitcoin/bitcoin.conf getblockchaininfo || exit 1

ENTRYPOINT ["/entrypoint.sh"]
